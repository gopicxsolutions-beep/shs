import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../models/loan.dart';
import '../../repositories/loan_repository.dart';
import '../../routes/paths.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/progress_bar.dart';

class LoanTrackingPage extends StatelessWidget {
  const LoanTrackingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final repo = LoanRepository();
    final memberId = appState.profile?.id;

    return Scaffold(
      appBar: const PageHeader(title: 'Loan Tracking'),
      body: AppAsyncBuilder<List<Loan>>(
        future: () => repo.fetchForMember(memberId),
        builder: (context, loans) {
          final active = loans.where((l) => l.status == 'active' || l.status == 'overdue').toList();
          if (active.isEmpty) {
            return const AppEmptyState(icon: Icons.trending_up_rounded, message: 'No active loans to track');
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: active.length,
            itemBuilder: (context, i) {
              final l = active[i];
              final paid = l.amount - l.outstanding;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Expanded(child: Text(l.purpose, style: AppTheme.sans(14, weight: FontWeight.w700))),
                        AppBadge(text: l.status, tone: l.status == 'overdue' ? BadgeTone.danger : BadgeTone.brand),
                      ]),
                      const SizedBox(height: 10),
                      Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('₹${l.outstanding}', style: AppTheme.display(18)),
                        Text('of ₹${l.amount}', style: AppTheme.sans(12, color: Neutral.c500)),
                      ]),
                      const SizedBox(height: 8),
                      AppProgressBar(value: paid, max: l.amount, tone: l.status == 'overdue' ? ProgressTone.danger : ProgressTone.gold),
                      const SizedBox(height: 12),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        if (l.nextDueDate != null)
                          AppBadge(text: 'EMI ₹${l.emi} due ${DateFormat('dd MMM yyyy').format(l.nextDueDate!)}', tone: BadgeTone.warning, dot: true),
                        GestureDetector(
                          onTap: () => context.go(Paths.loanDetail(l.id)),
                          child: Text('Details', style: AppTheme.sans(12, weight: FontWeight.w700, color: Brand.c600)),
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
}
