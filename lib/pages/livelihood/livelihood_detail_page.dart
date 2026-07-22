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
    final appState = context.watch<AppState>();
    return Scaffold(
      appBar: const PageHeader(title: 'Activity Detail'),
      body: AppAsyncBuilder<LivelihoodActivity?>(
        key: _key,
        future: () => _repo.fetchById(widget.activityId),
        builder: (context, activity) {
          if (activity == null) {
            return const AppEmptyState(icon: Icons.error_outline_rounded, message: 'This activity could not be found');
          }
          // `livelihood_write_self_leader_or_staff` (RLS) only lets the
          // activity's own member, the SHG's leader, or staff update it —
          // but `livelihood_select_shg_or_staff` lets every SHG member READ
          // every other member's activities (transparency, like savings/
          // loans), so any member could open a teammate's activity detail
          // page and see "Update Progress" with no ownership check, tap it,
          // and hit a silent RLS no-op (0 rows updated, no exception) that
          // looked like a successful save.
          final canUpdate = activity.memberId == appState.profile?.id || appState.user.role != Role.member;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                gradient: LinearGradient(colors: activity.profit >= 0 ? [Brand.c700, Brand.c600] : [Accent.red600, Accent.red500]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(activity.activityType, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                      AppBadge(text: activity.status, tone: BadgeTone.neutral),
                    ]),
                    const SizedBox(height: 6),
                    Text(activity.description ?? '', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9))),
                    const SizedBox(height: 12),
                    Text('${activity.profit < 0 ? '-' : ''}₹${NumberFormat('#,##,##0', 'en_IN').format(activity.profit.abs())} net', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text('${activity.profit >= 0 ? "Profit" : "Loss"} so far', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.75))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _infoTile('Investment', '₹${NumberFormat('#,##,##0', 'en_IN').format(activity.investment)}')),
                const SizedBox(width: 12),
                Expanded(child: _infoTile('Revenue', '₹${NumberFormat('#,##,##0', 'en_IN').format(activity.revenue)}')),
              ]),
              if (canUpdate) ...[
                const SizedBox(height: 20),
                AppButton(
                  label: 'Update Progress',
                  fullWidth: true,
                  onPressed: () => _updateProgress(context, activity),
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

  Future<void> _updateProgress(BuildContext context, LivelihoodActivity activity) async {
    final revenueController = TextEditingController(text: '${activity.revenue}');
    var status = activity.status;
    String? error;
    var submitting = false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Update progress'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: revenueController,
                keyboardType: TextInputType.number,
                inputFormatters: decimalAmountInputFormatters,
                textInputAction: TextInputAction.done,
                maxLength: 9,
                decoration: const InputDecoration(prefixText: '₹', labelText: 'Revenue to date', counterText: ''),
              ),
              const SizedBox(height: 12),
              DropdownButton<String>(
                value: status,
                isExpanded: true,
                items: _statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => status = v ?? status),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: submitting ? null : () => Navigator.of(context).pop(false), child: Text(AppLocalizations.of(context)?.actionCancel ?? 'Cancel')),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      final revenue = num.tryParse(revenueController.text);
                      if (revenue == null || revenue < 0) {
                        setState(() => error = 'Enter a valid revenue amount');
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
                            error = 'Could not save this update. Please try again.';
                          });
                        }
                      }
                    },
              child: Text(submitting ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      _key.currentState?.reload();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(SupabaseService.isConfigured ? 'Progress updated' : 'Demo mode — not saved (connect Supabase to persist)')),
        );
      }
    }
  }
}
