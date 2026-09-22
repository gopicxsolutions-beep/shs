import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/shg_join_request.dart';
import '../../repositories/shg_join_request_repository.dart';
import '../../routes/paths.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';

/// Shown to a member whose SHG join request hasn't been decided yet — see
/// `AppState.needsShgApproval` and the router redirect that gates on it.
class ShgApprovalPendingPage extends StatefulWidget {
  // Injectable for tests (same seam as MeetingSchedulePage/SavingsEntryPage)
  // — defaults to the real repository.
  final ShgJoinRequestRepository? repository;
  const ShgApprovalPendingPage({super.key, this.repository});
  @override
  State<ShgApprovalPendingPage> createState() => _ShgApprovalPendingPageState();
}

class _ShgApprovalPendingPageState extends State<ShgApprovalPendingPage> {
  late final _repo = widget.repository ?? ShgJoinRequestRepository();
  final GlobalKey<AppAsyncBuilderState<ShgJoinRequest?>> _key = GlobalKey();
  bool _checking = false;
  bool _withdrawing = false;

  Future<void> _checkStatus() async {
    setState(() => _checking = true);
    final appState = context.read<AppState>();
    try {
      await appState.refreshProfile();
      await _key.currentState?.reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.shgApprovalCheckError)));
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _withdraw(String requestId) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.shgApprovalWithdrawConfirmTitle),
        content: Text(l10n.shgApprovalWithdrawConfirmMessage),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.actionCancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.shgApprovalWithdrawButton)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _withdrawing = true);
    try {
      await _repo.withdraw(requestId);
      await _key.currentState?.reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.shgApprovalWithdrawError)));
      }
    } finally {
      if (mounted) setState(() => _withdrawing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final memberId = context.watch<AppState>().profile?.id;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Neutral.c50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: AppAsyncBuilder<ShgJoinRequest?>(
            key: _key,
            future: () => _repo.fetchMine(memberId),
            builder: (context, request) {
              // `request == null` is reachable even while the router still
              // gates on `needsShgApproval` (role='member', shgId=null):
              // that flag only checks profile state, not whether a request
              // row actually exists, and `shg_join_requests_delete_self_
              // pending` (migration 0033/0109) already lets a member
              // self-withdraw her own pending row via direct REST with no
              // in-app button routed through it yet. Previously this fell
              // into the same "waiting for approval" copy as a genuine
              // pending request — telling her to keep waiting for something
              // that no longer exists.
              final noRequest = request == null;
              final rejected = request?.status == 'rejected';
              // A live-observed real state (found while auditing this page
              // end to end, not hypothetical): `request.status == 'approved'`
              // yet the router still sent her here — `needsShgApproval` only
              // checks the CURRENT profile (`role == 'member' && shgId ==
              // null`), so this combination is only reachable when something
              // unlinked her from her SHG AFTER a genuine approval (e.g. an
              // admin's "Assign SHG" removal/reassignment — that action never
              // touches this now-stale `shg_join_requests` row, since it
              // doesn't go through `approve_shg_join_request` at all). Before
              // this fix, the code below had no explicit branch for
              // 'approved' at all, so it silently fell into the same
              // "waiting for approval" copy as a genuine first-time pending
              // request — telling an already-vetted, previously-active
              // member (with real savings/loan/attendance history) to sit
              // and wait for a decision that was already made and then
              // undone, with no explanation of what actually happened.
              final removed = request?.status == 'approved';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 64, height: 64,
                    margin: const EdgeInsets.symmetric(horizontal: 100),
                    decoration: BoxDecoration(
                      color: rejected || removed ? Accent.red50 : Gold.c50,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      rejected || removed ? Icons.cancel_rounded : (noRequest ? Icons.info_outline_rounded : Icons.hourglass_top_rounded),
                      color: rejected || removed ? Accent.red600 : Gold.c600,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    rejected
                        ? l10n.shgApprovalRejectedTitle
                        : (removed ? l10n.shgApprovalRemovedTitle : (noRequest ? l10n.shgApprovalNoneTitle : l10n.shgApprovalWaitingTitle)),
                    textAlign: TextAlign.center,
                    style: AppTheme.display(20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    rejected
                        ? l10n.shgApprovalRejectedMessage
                        : (removed ? l10n.shgApprovalRemovedMessage : (noRequest ? l10n.shgApprovalNoneMessage : l10n.shgApprovalWaitingMessage)),
                    textAlign: TextAlign.center,
                    style: AppTheme.sans(13, color: Neutral.c500),
                  ),
                  const SizedBox(height: 20),
                  if (request != null)
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.profileSHG, style: AppTheme.sans(11, weight: FontWeight.w700, color: Neutral.c500)),
                          const SizedBox(height: 2),
                          Text(request.shgName ?? l10n.unknownShg, style: AppTheme.sans(15, weight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  if (rejected)
                    AppButton(label: l10n.chooseDifferentShg, fullWidth: true, size: ButtonSize.lg, onPressed: () => context.go(Paths.profileSetup))
                  else if (removed)
                    // Deliberately NOT the "still waiting" button block below
                    // (Check Status / Withdraw) — her request is already
                    // decided ('approved'), so Check Status can never change
                    // anything, and Withdraw would silently no-op: `shg_join_
                    // requests_delete_self_pending`'s RLS only matches
                    // `status = 'pending'`, so the DELETE affects 0 rows and
                    // still returns success (see ShgJoinRequestRepository.
                    // withdraw's own hardening for this same class of bug).
                    AppButton(label: l10n.chooseAnShg, fullWidth: true, size: ButtonSize.lg, onPressed: () => context.go(Paths.profileSetup))
                  else if (noRequest)
                    AppButton(label: l10n.chooseAnShg, fullWidth: true, size: ButtonSize.lg, onPressed: () => context.go(Paths.profileSetup))
                  else ...[
                    AppButton(label: _checking ? l10n.checkingStatus : l10n.actionCheckStatus, fullWidth: true, size: ButtonSize.lg, onPressed: _checking ? null : _checkStatus),
                    const SizedBox(height: 12),
                    // A still-pending request previously had no escape at
                    // all here — only Check Status and Sign Out, neither of
                    // which lets a member who picked the wrong SHG (or whose
                    // leader never acts) change her mind. This mirrors the
                    // rejected-state button above; ShgJoinRequestRepository.
                    // submit() (see its own doc comment) now replaces the
                    // still-pending row instead of erroring on it.
                    AppButton(label: l10n.chooseDifferentShg, fullWidth: true, size: ButtonSize.lg, variant: ButtonVariant.outline, onPressed: () => context.go(Paths.profileSetup)),
                    const SizedBox(height: 12),
                    // Gap-hunt iteration 28: `shg_join_requests_delete_self_
                    // pending` (migration 0033/0109) has let a member cancel
                    // her own pending request via direct REST since it was
                    // written, but no in-app control ever called it — the
                    // only recourse was replacing it with a different SHG,
                    // never just stopping. Wires the same capability into a
                    // real button instead of leaving it a REST-only surface.
                    AppButton(
                      label: _withdrawing ? l10n.shgApprovalWithdrawing : l10n.shgApprovalWithdrawButton,
                      fullWidth: true,
                      size: ButtonSize.lg,
                      variant: ButtonVariant.outline,
                      onPressed: _withdrawing ? null : () => _withdraw(request.id),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () async {
                      try {
                        await context.read<AppState>().signOut();
                      } catch (_) {
                        // Fall through to navigate regardless — local session
                        // state is cleared even if the remote sign-out call fails.
                      }
                      if (context.mounted) context.go(Paths.splash);
                    },
                    child: Text(l10n.actionSignOut, style: AppTheme.sans(13, color: Neutral.c500)),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
