import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../models/loan.dart';
import '../../models/types.dart';
import '../../repositories/loan_repository.dart';
import '../../routes/paths.dart';
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
  const LoansHomePage({super.key});

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

    return Scaffold(
      appBar: PageHeader(
        title: 'Loans',
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
        right: isLeaderOrStaff ? null : IconButton(icon: const Icon(Icons.add_circle_rounded, color: Brand.c600), onPressed: () => context.go(Paths.loanApply), tooltip: 'Apply for a loan'),
      ),
      body: AppAsyncBuilder<List<Loan>>(
        future: () => isLeaderOrStaff ? repo.fetchForShg(shgId) : repo.fetchForMember(memberId),
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
                    label: isLeaderOrStaff ? 'Group Outstanding' : 'My Outstanding',
                    value: '₹${NumberFormat('#,##,##0', 'en_IN').format(outstanding)}',
                    tone: StatTone.gold,
                    trend: '${loans.length} loans',
                    icon: Icons.account_balance_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: isLeaderOrStaff ? 'Pending Approval' : 'Overdue',
                    value: '${isLeaderOrStaff ? pending : overdue}',
                    tone: overdue > 0 && !isLeaderOrStaff ? StatTone.danger : StatTone.brand,
                    trend: isLeaderOrStaff ? 'Needs review' : (overdue > 0 ? 'Action needed' : 'On track'),
                    icon: isLeaderOrStaff ? Icons.fact_check_rounded : Icons.warning_rounded,
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!isLeaderOrStaff) IconTile(onTap: () => context.go(Paths.loanApply), icon: Icons.add_circle_rounded, label: 'Apply', tone: TileTone.brand),
                  IconTile(onTap: () => context.go(Paths.loanTracking), icon: Icons.trending_up_rounded, label: 'Tracking', tone: TileTone.sky),
                  if (isLeaderOrStaff)
                    IconTile(
                      onTap: () => context.go(Paths.loanApproval),
                      icon: Icons.fact_check_rounded,
                      label: 'Approvals',
                      tone: TileTone.gold,
                      badge: pending > 0 ? '$pending' : null,
                      badgeSemanticLabel: pending > 0 ? 'Approvals, $pending pending' : null,
                    ),
                ],
              ),
              const SizedBox(height: 24),
              SectionHeader(title: isLeaderOrStaff ? 'All Loans' : 'My Loans'),
              if (loans.isEmpty)
                const AppEmptyState(icon: Icons.account_balance_rounded, message: 'No loans yet')
              else
                AppCard(
                  padded: false,
                  child: Column(
                    children: loans.map((l) {
                      return AppListRow(
                        leading: isLeaderOrStaff ? AppAvatar(name: l.memberName, size: 36) : null,
                        title: isLeaderOrStaff ? l.memberName : l.purpose,
                        subtitle: isLeaderOrStaff ? l.purpose : '₹${NumberFormat('#,##,##0', 'en_IN').format(l.outstanding)} of ₹${NumberFormat('#,##,##0', 'en_IN').format(l.amount)} outstanding',
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
