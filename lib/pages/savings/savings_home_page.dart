import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../models/savings.dart';
import '../../models/types.dart';
import '../../repositories/savings_repository.dart';
import '../../routes/paths.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/list_row.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_card.dart';

class SavingsHomePage extends StatelessWidget {
  const SavingsHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isLeaderOrStaff = appState.user.role != Role.member;
    final repo = SavingsRepository();
    final shgId = appState.profile?.shgId;
    final memberId = appState.profile?.id;

    return Scaffold(
      appBar: PageHeader(
        title: 'Savings',
        right: IconButton(
          icon: const Icon(Icons.add_circle_rounded, color: Brand.c600),
          onPressed: () => context.go(Paths.savingsEntry),
          tooltip: 'Add savings',
        ),
      ),
      body: AppAsyncBuilder<List<SavingsEntry>>(
        future: () => isLeaderOrStaff ? repo.fetchForShg(shgId) : repo.fetchForMember(memberId),
        builder: (context, entries) {
          final total = entries.fold<num>(0, (sum, e) => sum + e.amount);
          final pending = entries.where((e) => e.status == 'pending').length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Row(children: [
                Expanded(
                  child: StatCard(
                    label: isLeaderOrStaff ? 'Group Savings' : 'My Savings',
                    value: '₹${NumberFormat('#,##0').format(total)}',
                    tone: StatTone.brand,
                    trend: '${entries.length} entries',
                    icon: Icons.account_balance_wallet_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Pending Verification',
                    value: '$pending',
                    tone: StatTone.gold,
                    trend: pending > 0 ? 'Needs review' : 'All caught up',
                    icon: Icons.pending_actions_rounded,
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconTile(onTap: () => context.go(Paths.savingsEntry), icon: Icons.add_circle_rounded, label: 'Add Savings', tone: TileTone.brand),
                  IconTile(onTap: () => context.go(Paths.savingsHistory), icon: Icons.history_rounded, label: 'History', tone: TileTone.sky),
                  IconTile(onTap: () => context.go(Paths.savingsStatement), icon: Icons.receipt_long_rounded, label: 'Statement', tone: TileTone.violet),
                  IconTile(
                    onTap: () => context.go(isLeaderOrStaff ? Paths.savingsLedger : Paths.savingsGroupReport),
                    icon: isLeaderOrStaff ? Icons.fact_check_rounded : Icons.groups_rounded,
                    label: isLeaderOrStaff ? 'Ledger' : 'Group',
                    tone: TileTone.gold,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SectionHeader(
                title: 'Recent Entries',
                action: 'View all',
                onAction: () => context.go(isLeaderOrStaff ? Paths.savingsLedger : Paths.savingsHistory),
              ),
              if (entries.isEmpty)
                const AppEmptyState(icon: Icons.savings_rounded, message: 'No savings entries yet')
              else
                AppCard(
                  padded: false,
                  child: Column(
                    children: entries.take(8).map((e) {
                      return AppListRow(
                        leading: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(color: Brand.c50, borderRadius: BorderRadius.circular(10)),
                          alignment: Alignment.center,
                          child: Icon(Icons.arrow_downward_rounded, size: 16, color: Brand.c600),
                        ),
                        title: isLeaderOrStaff ? e.memberName : '${e.frequency} savings',
                        subtitle: '${DateFormat('dd MMM yyyy').format(e.date)} · ${e.mode}',
                        trailing: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('₹${e.amount}', style: AppTheme.sans(13, weight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            AppBadge(text: e.status, tone: e.status == 'verified' ? BadgeTone.success : BadgeTone.warning),
                          ],
                        ),
                        chevron: false,
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
