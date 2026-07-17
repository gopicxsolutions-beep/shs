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

const _statusTones = <String, BadgeTone>{
  'pending': BadgeTone.warning,
  'active': BadgeTone.brand,
  'overdue': BadgeTone.danger,
  'closed': BadgeTone.success,
  'rejected': BadgeTone.neutral,
};

class LoanStatementPage extends StatelessWidget {
  const LoanStatementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final memberId = context.watch<AppState>().profile?.id;
    final repo = LoanRepository();

    return Scaffold(
      appBar: const PageHeader(title: 'Loan Statement'),
      body: AppAsyncBuilder<List<Loan>>(
        future: () => repo.fetchForMember(memberId),
        builder: (context, loans) {
          if (loans.isEmpty) {
            return const AppEmptyState(icon: Icons.account_balance_rounded, message: 'No loans to statement yet');
          }
          final totalBorrowed = loans.fold<num>(0, (s, l) => s + l.amount);
          final totalOutstanding = loans.where((l) => l.status == 'active' || l.status == 'overdue').fold<num>(0, (s, l) => s + l.outstanding);
          final totalRepaid = totalBorrowed - loans.fold<num>(0, (s, l) => s + l.outstanding);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                gradient: const LinearGradient(colors: [Brand.c700, Brand.c600]),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Total Outstanding', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                      const SizedBox(height: 4),
                      Text('₹${NumberFormat('#,##0').format(totalOutstanding)}', style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w700)),
                    ]),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('${loans.length} loan(s)', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                      const SizedBox(height: 4),
                      Text('Repaid ₹${NumberFormat('#,##0').format(totalRepaid)}', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...loans.map((l) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      onTap: () => context.go(Paths.loanDetail(l.id)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Expanded(child: Text(l.purpose, style: AppTheme.sans(13, weight: FontWeight.w700))),
                            AppBadge(text: l.status, tone: _statusTones[l.status] ?? BadgeTone.neutral),
                          ]),
                          const SizedBox(height: 8),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text('Amount ₹${l.amount}', style: AppTheme.sans(12, color: Neutral.c500)),
                            Text('Outstanding ₹${l.outstanding}', style: AppTheme.sans(12, weight: FontWeight.w700, color: Brand.c600)),
                          ]),
                          if (l.disbursedOn != null) ...[
                            const SizedBox(height: 4),
                            Text('Disbursed ${DateFormat('dd MMM yyyy').format(l.disbursedOn!)}', style: AppTheme.sans(11, color: Neutral.c400)),
                          ],
                        ],
                      ),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }
}
