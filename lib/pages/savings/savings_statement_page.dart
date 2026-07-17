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
          if (entries.isEmpty) {
            return const Center(child: AppEmptyState(icon: Icons.receipt_long_rounded, message: 'No entries to statement yet'));
          }
          // Statement reads oldest → newest with a running balance.
          final chronological = entries.reversed.toList();
          final closingBalance = chronological.fold<num>(0, (sum, e) => sum + e.amount);
          var running = 0;
          final rows = chronological.map((e) {
            running += e.amount.round();
            return (e, running);
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                gradient: const LinearGradient(colors: [Brand.c700, Brand.c600]),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Closing Balance', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                        const SizedBox(height: 4),
                        Text('₹${NumberFormat('#,##0').format(closingBalance)}', style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${chronological.length} transactions', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                        const SizedBox(height: 4),
                        Text(
                          '${DateFormat('dd MMM yy').format(chronological.first.date)} – ${DateFormat('dd MMM yy').format(chronological.last.date)}',
                          style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                padded: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('DATE / MODE', style: AppTheme.sans(10, weight: FontWeight.w700, color: Neutral.c400)),
                        Text('AMOUNT / BALANCE', style: AppTheme.sans(10, weight: FontWeight.w700, color: Neutral.c400)),
                      ]),
                    ),
                    const Divider(height: 1, color: Neutral.c100),
                    ...rows.map((row) {
                      final (e, balance) = row;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(DateFormat('dd MMM yyyy').format(e.date), style: AppTheme.sans(12, weight: FontWeight.w700)),
                                Text(e.mode, style: AppTheme.sans(11, color: Neutral.c500)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('+₹${e.amount}', style: AppTheme.sans(12, weight: FontWeight.w700, color: Brand.c600)),
                                Text('₹$balance', style: AppTheme.sans(11, color: Neutral.c500)),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
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
