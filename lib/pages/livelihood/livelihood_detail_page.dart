import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/livelihood.dart';
import '../../models/types.dart';
import '../../repositories/livelihood_repository.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/input_formatters.dart';

const _statusOptions = ['planned', 'active', 'completed'];

class LivelihoodDetailPage extends StatefulWidget {
  final String activityId;
  const LivelihoodDetailPage({super.key, required this.activityId});
  @override
  State<LivelihoodDetailPage> createState() => _LivelihoodDetailPageState();
}

class _LivelihoodDetailPageState extends State<LivelihoodDetailPage> {
  final _repo = LivelihoodRepository();
  final _key = GlobalKey<AppAsyncBuilderState<LivelihoodActivity?>>();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    return Scaffold(
      appBar: PageHeader(title: l10n.livelihoodDetailTitle),
      body: AppAsyncBuilder<LivelihoodActivity?>(
        key: _key,
        future: () => _repo.fetchById(widget.activityId),
        builder: (context, activity) {
          if (activity == null) {
            return AppEmptyState(icon: Icons.error_outline_rounded, message: l10n.livelihoodDetailNotFoundMessage);
          }
          // `livelihood_write_self_leader_or_staff` (RLS) only lets the
          // activity's own member, the SHG's OWN leader, or staff update it
          // — but `livelihood_select_shg_or_staff` lets every SHG member
          // READ every other member's activities (transparency, like
          // savings/loans), so any member could open a teammate's activity
          // detail page and see "Update Progress" with no ownership check,
          // tap it, and hit a silent RLS no-op (0 rows updated, no
          // exception) that looked like a successful save. The leader
          // branch specifically must also be scoped to her OWN SHG — a
          // leader reaching a foreign-SHG activity's detail page (deep
          // link / typed URL with a known/guessed id on Flutter Web)
          // reproduced the identical silent-no-op-looks-like-success bug
          // for that role, since `appState.user.role != Role.member` was
          // true for ANY leader regardless of which SHG the activity
          // actually belongs to.
          final canUpdate = activity.memberId == appState.profile?.id ||
              appState.user.role == Role.crp ||
              appState.user.role == Role.clf ||
              appState.user.role == Role.admin ||
              (appState.user.role == Role.leader && activity.shgId == appState.profile?.shgId);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                gradient: LinearGradient(colors: activity.profit >= 0 ? [Brand.c700, Brand.c600] : [Accent.red600, Accent.red500]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Flexible(child: Text(livelihoodActivityTypeLabel(activity.activityType, l10n), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white))),
                      const SizedBox(width: 8),
                      AppBadge(text: livelihoodStatusLabel(activity.status, l10n), tone: livelihoodStatusTones[activity.status] ?? BadgeTone.neutral),
                    ]),
                    const SizedBox(height: 6),
                    Text(activity.description ?? '', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9))),
                    const SizedBox(height: 12),
                    Text(l10n.livelihoodDetailNetAmount('${activity.profit < 0 ? '-' : ''}₹${NumberFormat('#,##,##0', 'en_IN').format(activity.profit.abs())}'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text(activity.profit >= 0 ? l10n.livelihoodDetailProfitSoFar : l10n.livelihoodDetailLossSoFar, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.75))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _infoTile(l10n.livelihoodDetailInvestmentLabel, '₹${NumberFormat('#,##,##0', 'en_IN').format(activity.investment)}')),
                const SizedBox(width: 12),
                Expanded(child: _infoTile(l10n.livelihoodDetailRevenueLabel, '₹${NumberFormat('#,##,##0', 'en_IN').format(activity.revenue)}')),
              ]),
              if (canUpdate) ...[
                const SizedBox(height: 20),
                AppButton(
                  label: l10n.livelihoodDetailUpdateProgressButton,
                  fullWidth: true,
                  // `isStaff` here must also require non-ownership — RLS
                  // (`livelihood_update_self_leader_or_staff`, migration
                  // 0105) only leaves the fully-unrestricted staff branch
                  // open when `member_id <> auth.uid()`; a staff account
                  // editing HER OWN activity falls through to the same
                  // one-step-at-a-time restricted branch a plain member
                  // must obey. A role-only check here (as before) offered
                  // every status as reachable regardless, so picking a
                  // 2-step jump submitted and was rejected by the DB with
                  // only the generic save error, not pre-filtered out.
                  onPressed: () => _updateProgress(
                    context,
                    activity,
                    isStaff: appState.user.role != Role.member && appState.user.role != Role.leader && activity.memberId != appState.profile?.id,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _infoTile(String label, String value) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTheme.sans(11, color: Neutral.c500)),
            const SizedBox(height: 4),
            Text(value, style: AppTheme.sans(15, weight: FontWeight.w700)),
          ],
        ),
      );

  Future<void> _updateProgress(BuildContext context, LivelihoodActivity activity, {required bool isStaff}) async {
    final l10n = AppLocalizations.of(context)!;
    final revenueController = TextEditingController(text: '${activity.revenue}');
    var status = activity.status;
    // `livelihood_update_self_leader_or_staff` (RLS) only lets a non-staff
    // caller (the activity's own member, or her leader) move status one
    // step at a time (`abs(position diff) <= 1`) — staff has no such
    // restriction. Offering every status unconditionally let a member/
    // leader pick e.g. `completed` directly from `planned` and hit a
    // server-side RLS violation with only a generic "could not save"
    // message, instead of the reachable-only options this dialog now
    // shows (matching the established precedent in the marketplace order
    // status picker, which disables unreachable transitions the same way).
    final reachableOptions = isStaff
        ? _statusOptions
        : _statusOptions.where((s) => (_statusOptions.indexOf(s) - _statusOptions.indexOf(activity.status)).abs() <= 1).toList();
    String? error;
    var submitting = false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.livelihoodDetailDialogTitle),
          content: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: revenueController,
                keyboardType: TextInputType.number,
                inputFormatters: decimalAmountInputFormatters,
                textInputAction: TextInputAction.done,
                maxLength: 9,
                decoration: InputDecoration(prefixText: '₹', labelText: l10n.livelihoodDetailRevenueToDateLabel, counterText: ''),
              ),
              const SizedBox(height: 12),
              DropdownButton<String>(
                value: status,
                isExpanded: true,
                items: reachableOptions.map((s) => DropdownMenuItem(value: s, child: Text(livelihoodStatusLabel(s, l10n)))).toList(),
                onChanged: (v) => setState(() => status = v ?? status),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ],
            ),
          ),
          actions: [
            TextButton(onPressed: submitting ? null : () => Navigator.of(context).pop(false), child: Text(l10n.actionCancel)),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      final revenue = num.tryParse(revenueController.text);
                      if (revenue == null || revenue < 0) {
                        setState(() => error = l10n.livelihoodDetailInvalidRevenueError);
                        return;
                      }
                      // Mirrors the same DB-level cap (migration 0090) the
                      // entry page now also checks — this field was only
                      // bounded to 9 characters (~999,999,999), not by value.
                      if (revenue > 1000000) {
                        setState(() => error = l10n.livelihoodEntryInvestmentTooLarge);
                        return;
                      }
                      setState(() {
                        error = null;
                        submitting = true;
                      });
                      try {
                        await _repo.updateProgress(activity.id, revenue: revenue, status: status);
                        if (context.mounted) Navigator.of(context).pop(true);
                      } catch (_) {
                        if (context.mounted) {
                          setState(() {
                            submitting = false;
                            error = l10n.livelihoodDetailSaveError;
                          });
                        }
                      }
                    },
              child: Text(submitting ? l10n.livelihoodDetailSavingButton : l10n.livelihoodDetailSaveButton),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      _key.currentState?.reload();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(SupabaseService.isConfigured ? l10n.livelihoodDetailProgressUpdatedMessage : l10n.livelihoodDetailDemoModeMessage)),
        );
      }
    }
  }
}
