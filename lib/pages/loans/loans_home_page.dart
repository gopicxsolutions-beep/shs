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
import '../../theme/app_theme.dart';
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
    final appState = context.watch<AppState>();
    final isLeaderOrStaff = appState.user.role != Role.member;
    final repo = LoanRepository();
    final shgId = appState.profile?.shgId;
    final memberId = appState.profile?.id;

    return Scaffold(
      appBar: PageHeader(
        title: 'Loans',
        right: IconButton(icon: const Icon(Icons.add_circle_rounded, color: Brand.c600), onPressed: () => context.go(Paths.loanApply)),
      ),
      body: AppAsyncBuilder<List<Loan>>(
        future: () => isLeaderOrStaff ? repo.fetchForShg(shgId) : repo.fetchForMember(memberId),
        builder: (context, loans) {
          final outstanding = loans.fold<num>(0, (sum, l) => sum + l.outstanding);
          final pending = loans.where((l) => l.status == 'pending').length;
          final overdue = loans.where((l) => l.status == 'overdue').length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Row(children: [
                Expanded(
                  child: StatCard(
                    label: isLeaderOrStaff ? 'Group Outstanding' : 'My Outstanding',
                    value: '₹${NumberFormat('#,##0').format(outstanding)}',
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
                  IconTile(onTap: () => context.go(Paths.loanApply), icon: Icons.add_circle_rounded, label: 'Apply', tone: TileTone.brand),
                  IconTile(onTap: () => context.go(Paths.loanTracking), icon: Icons.trending_up_rounded, label: 'Tracking', tone: TileTone.sky),
                  if (isLeaderOrStaff)
                    IconTile(
                      onTap: () => context.go(Paths.loanApproval),
                      icon: Icons.fact_check_rounded,
                      label: 'Approvals',
                      tone: TileTone.gold,
                      badge: pending > 0 ? '$pending' : null,
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
                        subtitle: isLeaderOrStaff ? l.purpose : '₹${l.outstanding} of ₹${l.amount} outstanding',
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
