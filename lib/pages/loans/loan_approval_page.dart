import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/loan.dart';
import '../../models/types.dart';
import '../../repositories/loan_repository.dart' show LoanAlreadyDecidedException, LoanRepository;
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/avatar.dart';
import '../../widgets/input_formatters.dart';

class LoanApprovalPage extends StatefulWidget {
  // Injectable so the platform-wide staff approval queue (live-mode-only)
  // can be widget-tested against canned cross-SHG data instead of a real
  // network call — defaults to a real LoanRepository.
  final LoanRepository? repository;
  const LoanApprovalPage({super.key, this.repository});
  @override
  State<LoanApprovalPage> createState() => _LoanApprovalPageState();
}

class _LoanApprovalPageState extends State<LoanApprovalPage> {
  late final LoanRepository _repo = widget.repository ?? LoanRepository();
  final _key = GlobalKey<AppAsyncBuilderState<List<Loan>>>();
  final _rejecting = <String>{};
  final _approving = <String>{};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    final role = appState.user.role;
    final shgId = appState.profile?.shgId;
    final myId = appState.profile?.id;

    // Router-restricted to leader/staff already, but crp/clf/admin have no
    // `profile.shgId` of their own. `loans_update_leader_or_staff` (RLS) has
    // always granted `is_staff()` unrestricted platform-wide approve/reject
    // rights — the same capability loans_home_page.dart's platform-wide
    // portfolio now surfaces — so rather than `fetchForShg(null)`'s
    // permanently-empty queue (or the honest-but-dead-end message that
    // replaced it), fetch every SHG's pending applications instead.
    // `isConfigured` excludes demo mode, whose simulated identity leaves
    // `shgId` null for every previewed role too.
    //
    // Gated on actual is_staff() (crp/clf/admin), not just `shgId == null` —
    // a LEADER with a null shgId is an unlinked account (see the guard
    // below), never legitimately platform-wide; RLS already excludes
    // 'leader' from `is_staff()` regardless of this flag.
    final isPlatformWide = SupabaseService.isConfigured && role != Role.member && role != Role.leader && shgId == null;

    if (SupabaseService.isConfigured && role == Role.leader && shgId == null) {
      return Scaffold(
        appBar: PageHeader(title: l10n.loanApprovalTitle),
        body: AppEmptyState(icon: Icons.fact_check_rounded, message: l10n.commonLeaderNoShgMessage),
      );
    }

    return Scaffold(
      appBar: PageHeader(title: l10n.loanApprovalTitle),
      body: AppAsyncBuilder<List<Loan>>(
        key: _key,
        future: () => isPlatformWide ? _repo.fetchAllForStaff() : _repo.fetchForShg(shgId),
        builder: (context, loans) {
          // `loans_update_leader_or_staff` (RLS) requires the loan's own
          // member to NOT be the caller — a leader can never approve/reject
          // her own loan (no identity may escalate itself). Without this
          // filter her own self-applied loan sat in this list looking
          // actionable, and tapping Approve/Reject always failed with a
          // generic "please try again" that gave no hint why — found via
          // live end-to-end testing, not visible in demo mode or code review
          // alone, since demo mode has no real per-user identity to collide.
          final pending = loans.where((l) => l.status == 'pending' && l.memberId != myId).toList();
          if (pending.isEmpty) {
            return AppEmptyState(icon: Icons.fact_check_rounded, message: l10n.loanApprovalEmptyMessage);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pending.length,
            itemBuilder: (context, i) {
              final l = pending[i];
              final rejecting = _rejecting.contains(l.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        AppAvatar(name: l.memberName, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.memberName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(14, weight: FontWeight.w700)),
                              Text(l.purpose, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(12, color: Neutral.c500)),
                            ],
                          ),
                        ),
                        // Was a bare Text, not wrapped in Flexible — at
                        // 1.3x-2x text scale a large loan amount (cap
                        // ₹10,00,000) next to the fixed 40px avatar could
                        // overflow the Row, since only the middle column
                        // shrinks. loan_tracking_page.dart's equivalent
                        // amount text already wraps in Flexible; matching
                        // that here.
                        Flexible(child: Text('₹${NumberFormat('#,##,##0', 'en_IN').format(l.amount)}', style: AppTheme.display(16), overflow: TextOverflow.ellipsis)),
                      ]),
                      const SizedBox(height: 4),
                      Text(l10n.loanApprovalTenureMonths(l.tenureMonths), style: AppTheme.sans(11, color: Neutral.c400)),
                      if (isPlatformWide && l.shgName != null) ...[
                        const SizedBox(height: 2),
                        Text(l10n.loanApprovalShgName(l.shgName!), style: AppTheme.sans(11, color: Neutral.c400)),
                      ],
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: AppButton(
                            variant: ButtonVariant.danger,
                            label: rejecting ? l10n.loanApprovalRejectingButton : l10n.loanApprovalRejectButton,
                            onPressed: rejecting
                                ? null
                                : () async {
                                    setState(() => _rejecting.add(l.id));
                                    try {
                                      await _repo.reject(l.id);
                                      _key.currentState?.reload();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(SupabaseService.isConfigured ? l10n.loanApprovalRejectedMessage : l10n.loanApprovalDemoModeMessage)),
                                        );
                                      }
                                    } on LoanAlreadyDecidedException {
                                      // Someone else (another leader/staff account) already
                                      // approved or rejected this loan since the list was
                                      // last loaded — reload so the now-stale row drops out
                                      // of the pending queue instead of leaving it sitting
                                      // there looking actionable.
                                      _key.currentState?.reload();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(l10n.loanApprovalAlreadyDecidedRejectMessage)),
                                        );
                                      }
                                    } catch (_) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(l10n.loanApprovalRejectErrorMessage)),
                                        );
                                      }
                                    } finally {
                                      if (mounted) setState(() => _rejecting.remove(l.id));
                                    }
                                  },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppButton(
                            label: l10n.loanApprovalApproveButton,
                            // Mirrors Reject's `_rejecting` guard — without it, a
                            // fast double-tap could open two stacked Approve
                            // dialogs for the same loan before the first
                            // resolves (the RPC's own race guard would still
                            // prevent a bad outcome, but the second dialog would
                            // surface a confusing "already decided" error for
                            // what was really just a double-tap, not a genuine
                            // race with another leader/staff account).
                            onPressed: _approving.contains(l.id) ? null : () => _approve(context, l),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _approve(BuildContext context, Loan l) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final suggestedEmi = (l.amount / l.tenureMonths).ceil();
    final emiController = TextEditingController(text: '$suggestedEmi');
    String? error;
    var submitting = false;
    setState(() => _approving.add(l.id));
    final approved = await showDialog<bool>(
      context: context,
      // See shg_home_page.dart's identical fix for why: an accidental tap
      // just outside the dialog card otherwise silently discards the EMI
      // typed so far, indistinguishable from a real save failing.
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.loanApprovalDialogTitle),
          content: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.loanApprovalDialogEmiForMember(l.memberName), style: AppTheme.sans(12, color: Neutral.c500)),
              const SizedBox(height: 8),
              TextField(
                controller: emiController,
                keyboardType: TextInputType.number,
                inputFormatters: decimalAmountInputFormatters,
                textInputAction: TextInputAction.done,
                maxLength: 7,
                decoration: InputDecoration(prefixText: '₹', labelText: l10n.loanApprovalEmiLabel, counterText: ''),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ],
            ),
          ),
          actions: [
            TextButton(onPressed: submitting ? null : () => Navigator.of(context).pop(null), child: Text(l10n.actionCancel)),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      final emi = num.tryParse(emiController.text);
                      if (emi == null || emi <= 0) {
                        setState(() => error = l10n.loanApprovalInvalidEmiError);
                        return;
                      }
                      setState(() {
                        error = null;
                        submitting = true;
                      });
                      try {
                        await _repo.approve(l.id, emi: emi, nextDueDate: DateTime.now().add(const Duration(days: 30)));
                        if (context.mounted) Navigator.of(context).pop(true);
                      } on LoanAlreadyDecidedException {
                        // Another leader/staff account already approved or rejected
                        // this loan since the queue was loaded — retrying with a
                        // different EMI won't help, so close the dialog and let the
                        // reload below drop the now-stale row from the pending list.
                        if (context.mounted) Navigator.of(context).pop(false);
                      } catch (_) {
                        if (context.mounted) {
                          setState(() {
                            submitting = false;
                            error = l10n.loanApprovalApproveErrorMessage;
                          });
                        }
                      }
                    },
              child: Text(submitting ? l10n.loanApprovalApprovingButton : l10n.loanApprovalApproveButton),
            ),
          ],
        ),
      ),
    );
    if (mounted) setState(() => _approving.remove(l.id));
    if (approved == true) {
      _key.currentState?.reload();
      messenger.showSnackBar(
        SnackBar(content: Text(SupabaseService.isConfigured ? l10n.loanApprovalApprovedMessage : l10n.loanApprovalDemoModeMessage)),
      );
    } else if (approved == false) {
      _key.currentState?.reload();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.loanApprovalAlreadyDecidedApproveMessage)),
      );
    }
  }
}
