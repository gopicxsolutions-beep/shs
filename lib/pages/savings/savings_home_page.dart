import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    final isLeaderOrStaff = appState.user.role != Role.member;
    final repo = SavingsRepository();
    final shgId = appState.profile?.shgId;
    final memberId = appState.profile?.id;

    return Scaffold(
      appBar: PageHeader(
        title: l10n.savingsHomeTitle,
        right: IconButton(
          icon: const Icon(Icons.add_circle_rounded, color: Brand.c600),
          onPressed: () => context.go(Paths.savingsEntry),
          tooltip: l10n.savingsHomeAddTooltip,
        ),
      ),
      body: AppAsyncBuilder<List<SavingsEntry>>(
        future: () => isLeaderOrStaff ? repo.fetchForShg(shgId) : repo.fetchForMember(memberId),
        builder: (context, entries) {
          // Only verified entries count toward the confirmed total — a
          // pending entry is an unconfirmed self-report the SHG leader
          // hasn't reconciled yet, still shown in the list below but not
          // counted as settled savings.
          final total = entries.where((e) => e.status == 'verified').fold<num>(0, (sum, e) => sum + e.amount);
          final pending = entries.where((e) => e.status == 'pending').length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Row(children: [
                Expanded(
                  child: StatCard(
                    label: isLeaderOrStaff ? l10n.savingsHomeGroupSavingsLabel : l10n.savingsHomeMySavingsLabel,
                    value: '₹${NumberFormat('#,##,##0', 'en_IN').format(total)}',
                    tone: StatTone.brand,
                    trend: l10n.savingsHomeEntriesCount(entries.length),
                    icon: Icons.account_balance_wallet_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: l10n.savingsHomePendingVerificationLabel,
                    value: '$pending',
                    tone: StatTone.gold,
                    trend: pending > 0 ? l10n.savingsHomeNeedsReview : l10n.savingsHomeAllCaughtUp,
                    icon: Icons.pending_actions_rounded,
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconTile(onTap: () => context.go(Paths.savingsEntry), icon: Icons.add_circle_rounded, label: l10n.savingsHomeAddSavingsTile, tone: TileTone.brand),
                  IconTile(onTap: () => context.go(isLeaderOrStaff ? Paths.savingsLedger : Paths.savingsHistory), icon: Icons.history_rounded, label: l10n.savingsHomeHistoryTile, tone: TileTone.sky),
                  IconTile(onTap: () => context.go(Paths.savingsStatement), icon: Icons.receipt_long_rounded, label: l10n.savingsHomeStatementTile, tone: TileTone.violet),
                  IconTile(
                    onTap: () => context.go(isLeaderOrStaff ? Paths.savingsLedger : Paths.savingsGroupReport),
                    icon: isLeaderOrStaff ? Icons.fact_check_rounded : Icons.groups_rounded,
                    label: isLeaderOrStaff ? l10n.savingsHomeLedgerTile : l10n.savingsHomeGroupTile,
                    tone: TileTone.gold,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SectionHeader(
                title: l10n.savingsHomeRecentEntriesTitle,
                action: l10n.savingsHomeViewAllAction,
                onAction: () => context.go(isLeaderOrStaff ? Paths.savingsLedger : Paths.savingsHistory),
              ),
              if (entries.isEmpty)
                AppEmptyState(icon: Icons.savings_rounded, message: l10n.savingsHomeEmpty)
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
                        title: isLeaderOrStaff ? e.memberName : l10n.savingsFrequencyEntryTitle(e.frequency),
                        subtitle: '${DateFormat('dd MMM yyyy').format(e.date)} · ${e.mode}',
                        trailing: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('₹${NumberFormat('#,##,##0', 'en_IN').format(e.amount)}', style: AppTheme.sans(13, weight: FontWeight.w700)),
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
