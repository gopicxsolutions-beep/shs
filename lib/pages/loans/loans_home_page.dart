import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/loan.dart';
import '../../models/types.dart';
import '../../repositories/loan_repository.dart';
import '../../routes/paths.dart';
import '../../services/notification_service.dart';
import '../../state/app_state.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/avatar.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/list_row.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_card.dart';

const _statusTones = <String, BadgeTone>{
  'pending': BadgeTone.warning,
  'active': BadgeTone.brand,
  'overdue': BadgeTone.danger,
  'closed': BadgeTone.success,
  'rejected': BadgeTone.neutral,
};

class LoansHomePage extends StatelessWidget {
  // Injectable for tests (mirrors `SettingsPage`'s `notificationService`
  // seam) — defaults to the real on-device implementation.
  final NotificationService? notificationService;
  const LoansHomePage({super.key, this.notificationService});

  /// Fetches the loans this page actually displays (group-wide for a
  /// leader/staff account, own-only for a member), and — best-effort,
  /// without blocking the list from rendering — brings this device's
  /// scheduled loan-due reminders in line with *this member's own* loans
  /// (never the whole group's: a due-date reminder is inherently personal).
  /// For a member, that's exactly the list already being displayed, so it's
  /// reused rather than fetched twice; a leader/staff account still gets
  /// their own personal reminders synced even though the page itself is
  /// showing the group's loans.
  ///
  /// Before deciding, this also (a) proactively requests the OS notification
  /// permission the first time this ever loads with the preference still at
  /// its untouched, enabled-by-default state — see
  /// `ensureNotificationPermissionForDefaultEnabled`'s doc comment — instead
  /// of only ever asking reactively when a member happens to visit Settings,
  /// and (b) retries a previous toggle-off cancellation that failed
  /// part-way (`loanCancelPending`) instead of leaving it silently and
  /// permanently stranded — see `SettingsPage._onSavingsToggle`'s doc
  /// comment for the full bug write-up both of these fix.
  ///
  /// Bug fix: the permission-check-and-sync step below used to be `await`ed
  /// before returning `loans` to `AppAsyncBuilder`, so the list this method
  /// is documented as "without blocking...rendering" was in fact held
  /// behind the real on-device OS permission round trip — which, in an
  /// environment with no native counterpart to ever answer it (this app's
  /// own `flutter test` suite, whenever this page's default real
  /// [LocalNotificationService.instance] is exercised without an injected
  /// fake), never resolves at all and hung `pumpAndSettle` forever. Firing
  /// it off with [unawaited] instead means the already-fetched `loans`
  /// render immediately no matter how long (or whether) that ever resolves.
  Future<List<Loan>> _loadAndSyncReminders(LoanRepository repo, bool isLeaderOrStaff, String? shgId, String? memberId, NotificationService notifications) async {
    final loans = await (isLeaderOrStaff ? repo.fetchForShg(shgId) : repo.fetchForMember(memberId));
    unawaited(_syncReminders(repo, isLeaderOrStaff, memberId, loans, notifications));
    return loans;
  }

  Future<void> _syncReminders(LoanRepository repo, bool isLeaderOrStaff, String? memberId, List<Loan> loans, NotificationService notifications) async {
    final enabled = await ensureNotificationPermissionForDefaultEnabled(notifications, kNotifyPaymentsPrefKey, await paymentAlertsEnabled());
    if (enabled) {
      final ownLoans = isLeaderOrStaff ? await repo.fetchForMember(memberId) : loans;
      await syncLoanDueReminders(notifications, ownLoans);
    } else if (await loanCancelPending()) {
      final ownLoans = isLeaderOrStaff ? await repo.fetchForMember(memberId) : loans;
      await _retryPendingCancellation(notifications, ownLoans);
    }
  }

  /// Retries a cancellation `SettingsPage._onSavingsToggle` started but
  /// couldn't confirm succeeded — cancels every one of this member's own
  /// loan due-date reminders again and, only on success, clears the pending
  /// flag so this doesn't keep retrying forever once it's actually done.
  Future<void> _retryPendingCancellation(NotificationService notifications, List<Loan> ownLoans) async {
    try {
      await cancelAllLoanDueReminders(notifications, ownLoans);
      await setLoanCancelPending(false);
    } catch (_) {
      // Still pending — tried again the next time this page loads.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only role/shgId/memberId are used below — `.watch<AppState>()` would
    // rebuild this whole page, including the non-lazy `loans.map(...)` list
    // of every loan row plus the three `.where().fold()`/`.length` passes
    // over it, on every unrelated AppState change (e.g. the periodic
    // token-refresh notify in app_state.dart's `_authSub`), even though
    // nothing displayed here depends on it. `.select` only rebuilds when
    // one of these three fields actually changes.
    final isLeaderOrStaff = context.select<AppState, bool>((s) => s.user.role != Role.member);
    final shgId = context.select<AppState, String?>((s) => s.profile?.shgId);
    final memberId = context.select<AppState, String?>((s) => s.profile?.id);
    final repo = LoanRepository();
    final notifications = notificationService ?? LocalNotificationService.instance;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: PageHeader(
        title: l10n.loansHomeTitle,
        // This page is the group/staff overview when isLeaderOrStaff (title,
        // stats, and list rows all switch to group data throughout) — the
        // "Approvals" tile below is already correctly leader/staff-only;
        // "Apply" was the one asymmetric affordance still shown to everyone
        // regardless of role. Harmless in live mode (a leader IS still a
        // real SHG member and `loans_insert_self` RLS would legitimately
        // allow it), but in DEMO mode it produced a genuinely confusing
        // bug: demo mode's simulated identity doesn't vary with the
        // "Preview as" role switcher (`AppState.profile` stays null for
        // every previewed role), so applying while previewing as
        // Leader/CRP/CLF/Admin silently created a loan attributed to the
        // same hardcoded "Lakshmi Devi" demo persona — then reappeared in
        // that persona's own "My Loans" list after switching back to
        // Member, indistinguishable from something genuinely self-applied.
        right: isLeaderOrStaff ? null : IconButton(icon: const Icon(Icons.add_circle_rounded, color: Brand.c600), onPressed: () => context.go(Paths.loanApply), tooltip: l10n.loansHomeApplyTooltip),
      ),
      body: AppAsyncBuilder<List<Loan>>(
        future: () => _loadAndSyncReminders(repo, isLeaderOrStaff, shgId, memberId, notifications),
        builder: (context, loans) {
          // A pending or rejected loan's `outstanding` is set to the full
          // requested amount (never disbursed, so never reduced by a
          // payment) — summing every loan regardless of status counted an
          // application that was never approved, or was explicitly
          // rejected, as real owed debt. Only active/overdue loans have
          // actually been disbursed and carry a genuine outstanding balance.
          final outstanding = loans.where((l) => l.status == 'active' || l.status == 'overdue').fold<num>(0, (sum, l) => sum + l.outstanding);
          final pending = loans.where((l) => l.status == 'pending').length;
          final overdue = loans.where((l) => l.status == 'overdue').length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Row(children: [
                Expanded(
                  child: StatCard(
                    label: isLeaderOrStaff ? l10n.loansHomeGroupOutstandingLabel : l10n.loansHomeMyOutstandingLabel,
                    value: '₹${NumberFormat('#,##,##0', 'en_IN').format(outstanding)}',
                    tone: StatTone.gold,
                    trend: l10n.loansHomeLoanCount(loans.length),
                    icon: Icons.account_balance_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: isLeaderOrStaff ? l10n.loansHomePendingApprovalLabel : l10n.loansHomeOverdueLabel,
                    value: '${isLeaderOrStaff ? pending : overdue}',
                    tone: overdue > 0 && !isLeaderOrStaff ? StatTone.danger : StatTone.brand,
                    trend: isLeaderOrStaff ? l10n.loansHomeNeedsReviewTrend : (overdue > 0 ? l10n.loansHomeActionNeededTrend : l10n.loansHomeOnTrackTrend),
                    icon: isLeaderOrStaff ? Icons.fact_check_rounded : Icons.warning_rounded,
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!isLeaderOrStaff) IconTile(onTap: () => context.go(Paths.loanApply), icon: Icons.add_circle_rounded, label: l10n.loansHomeApplyLabel, tone: TileTone.brand),
                  IconTile(onTap: () => context.go(Paths.loanTracking), icon: Icons.trending_up_rounded, label: l10n.loansHomeTrackingLabel, tone: TileTone.sky),
                  if (isLeaderOrStaff)
                    IconTile(
                      onTap: () => context.go(Paths.loanApproval),
                      icon: Icons.fact_check_rounded,
                      label: l10n.loansHomeApprovalsLabel,
                      tone: TileTone.gold,
                      badge: pending > 0 ? '$pending' : null,
                      badgeSemanticLabel: pending > 0 ? l10n.loansHomeApprovalsBadgeSemanticLabel(pending) : null,
                    ),
                ],
              ),
              const SizedBox(height: 24),
              SectionHeader(title: isLeaderOrStaff ? l10n.loansHomeAllLoansTitle : l10n.loansHomeMyLoansTitle),
              if (loans.isEmpty)
                AppEmptyState(icon: Icons.account_balance_rounded, message: l10n.loansHomeEmptyMessage)
              else
                AppCard(
                  padded: false,
                  child: Column(
                    children: loans.map((l) {
                      return AppListRow(
                        leading: isLeaderOrStaff ? AppAvatar(name: l.memberName, size: 36) : null,
                        title: isLeaderOrStaff ? l.memberName : l.purpose,
                        subtitle: isLeaderOrStaff ? l.purpose : l10n.loansHomeOutstandingOfAmount(NumberFormat('#,##,##0', 'en_IN').format(l.outstanding), NumberFormat('#,##,##0', 'en_IN').format(l.amount)),
                        trailing: AppBadge(text: l.status, tone: _statusTones[l.status] ?? BadgeTone.neutral),
                        onTap: () => context.go(Paths.loanDetail(l.id)),
                      );
                    }).toList(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
