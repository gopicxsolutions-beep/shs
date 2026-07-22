import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../models/savings.dart';
import '../../repositories/savings_repository.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';

class SavingsStatementPage extends StatelessWidget {
  const SavingsStatementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final repo = SavingsRepository();
    final memberId = appState.profile?.id;

    return Scaffold(
      appBar: const PageHeader(title: 'Savings Statement'),
      body: AppAsyncBuilder<List<SavingsEntry>>(
        future: () => repo.fetchForMember(memberId),
        builder: (context, entries) {
          // Only verified entries count toward the statement — a pending
          // entry is an unconfirmed self-report the SHG leader hasn't
          // reconciled yet. Every other place that totals savings (Savings
          // Home's "My Savings" stat, the Group Report, ReportRepository's
          // member/SHG reports) already applies this same filter; this
          // formal statement page — reused as-is for the Reports module's
          // "Savings Statement" — previously summed every entry regardless
          // of status, so an unverified deposit could inflate the member's
          // own "Closing Balance" figure and leave no way to tell a pending
          // row apart from a confirmed one in the transaction list.
          final verified = entries.where((e) => e.status == 'verified').toList();
          if (verified.isEmpty) {
            return const Center(child: AppEmptyState(icon: Icons.receipt_long_rounded, message: 'No entries to statement yet'));
          }
          // Statement reads oldest → newest with a running balance.
          final chronological = verified.reversed.toList();
          final closingBalance = chronological.fold<num>(0, (sum, e) => sum + e.amount);
          num running = 0;
          final rows = chronological.map((e) {
            running += e.amount;
            return (e, running);
          }).toList();

          // CustomScrollView/Sliver split so the transaction list is
          // genuinely lazily built (SliverList.builder) instead of every
          // row regardless of scroll position — a multi-year member could
          // have hundreds of entries. The table "card" (header row + all
          // transaction rows) used to be one AppCard; DecoratedSliver
          // reproduces AppCard's exact decoration around the
          // header+rows sliver group so it still reads as one continuous
          // rounded card, not two visually separate pieces. Data is still
          // fetched and summed in full above (closingBalance/running) —
          // only the widget *building* is lazy now, not the query.
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: AppCard(
                        gradient: const LinearGradient(colors: [Brand.c700, Brand.c600]),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Closing Balance', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                                  const SizedBox(height: 4),
                                  Text(
                                    '₹${NumberFormat('#,##,##0', 'en_IN').format(closingBalance)}',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('${chronological.length} transactions', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${DateFormat('dd MMM yy').format(chronological.first.date)} – ${DateFormat('dd MMM yy').format(chronological.last.date)}',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    DecoratedSliver(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Neutral.c100.withValues(alpha: 0.6)),
                        boxShadow: cardShadow,
                      ),
                      sliver: SliverMainAxisGroup(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                    Flexible(child: Text('DATE / MODE', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(10, weight: FontWeight.w700, color: Neutral.c400))),
                                    const SizedBox(width: 8),
                                    Flexible(child: Text('AMOUNT / BALANCE', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end, style: AppTheme.sans(10, weight: FontWeight.w700, color: Neutral.c400))),
                                  ]),
                                ),
                                const Divider(height: 1, color: Neutral.c100),
                              ],
                            ),
                          ),
                          SliverList.builder(
                            itemCount: rows.length,
                            itemBuilder: (context, index) {
                              final (e, balance) = rows[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(DateFormat('dd MMM yyyy').format(e.date), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(12, weight: FontWeight.w700)),
                                          Text(e.mode, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(11, color: Neutral.c500)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text('+₹${NumberFormat('#,##,##0', 'en_IN').format(e.amount)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(12, weight: FontWeight.w700, color: Brand.c600)),
                                          Text('₹${NumberFormat('#,##,##0', 'en_IN').format(balance)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(11, color: Neutral.c500)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
