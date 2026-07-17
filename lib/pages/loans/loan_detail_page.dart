import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../layout/page_header.dart';
import '../../models/loan.dart';
import '../../repositories/loan_repository.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/progress_bar.dart';
import '../../widgets/section_header.dart';

class LoanDetailPage extends StatelessWidget {
  final String loanId;
  const LoanDetailPage({super.key, required this.loanId});

  @override
  Widget build(BuildContext context) {
    final repo = LoanRepository();
    final key = GlobalKey<AppAsyncBuilderState<Loan?>>();

    return Scaffold(
      appBar: const PageHeader(title: 'Loan Detail'),
      body: AppAsyncBuilder<Loan?>(
        key: key,
        future: () => repo.fetchById(loanId),
        builder: (context, loan) {
          if (loan == null) {
            return const AppEmptyState(icon: Icons.error_outline_rounded, message: 'This loan could not be found');
          }
          final paid = loan.amount - loan.outstanding;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                gradient: LinearGradient(colors: loan.status == 'overdue' ? [Accent.red600, Accent.red500] : [Brand.c700, Brand.c600]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Expanded(child: Text(loan.purpose, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white))),
                      AppBadge(text: loan.status, tone: BadgeTone.neutral),
                    ]),
                    const SizedBox(height: 12),
                    Text('₹${loan.outstanding}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text('outstanding of ₹${loan.amount}', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                    const SizedBox(height: 12),
                    AppProgressBar(value: paid, max: loan.amount, tone: ProgressTone.info),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _infoTile('EMI', '₹${loan.emi}')),
                const SizedBox(width: 12),
                Expanded(child: _infoTile('Tenure', '${loan.tenureMonths} months')),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _infoTile('Disbursed', loan.disbursedOn != null ? DateFormat('dd MMM yyyy').format(loan.disbursedOn!) : '—')),
                const SizedBox(width: 12),
                Expanded(child: _infoTile('Next Due', loan.nextDueDate != null ? DateFormat('dd MMM yyyy').format(loan.nextDueDate!) : '—')),
              ]),
              if (loan.status == 'active' || loan.status == 'overdue') ...[
                const SizedBox(height: 20),
                AppButton(
                  label: 'Record Payment',
                  fullWidth: true,
                  onPressed: !SupabaseService.isConfigured ? null : () => _recordPayment(context, repo, loan, key),
                ),
              ],
              const SizedBox(height: 24),
              const SectionHeader(title: 'Payment History'),
              AppAsyncBuilder<List<LoanPayment>>(
                future: () => repo.fetchPayments(loanId),
                builder: (context, payments) {
                  if (payments.isEmpty) {
                    return const AppEmptyState(icon: Icons.receipt_long_rounded, message: 'No payments recorded yet');
                  }
                  return AppCard(
                    padded: false,
                    child: Column(
                      children: payments.map((p) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text(DateFormat('dd MMM yyyy').format(p.paidOn), style: AppTheme.sans(13, weight: FontWeight.w600)),
                            Text('₹${p.amount}', style: AppTheme.sans(13, weight: FontWeight.w700, color: Brand.c600)),
                          ]),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _infoTile(String label, String value) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTheme.sans(11, color: Neutral.c500)),
            const SizedBox(height: 4),
            Text(value, style: AppTheme.sans(15, weight: FontWeight.w700)),
          ],
        ),
      );

  Future<void> _recordPayment(BuildContext context, LoanRepository repo, Loan loan, GlobalKey<AppAsyncBuilderState<Loan?>> key) async {
    final controller = TextEditingController(text: '${loan.emi}');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record payment'),
        content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(prefixText: '₹')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Record')),
        ],
      ),
    );
    if (confirmed != true) return;
    final amount = num.tryParse(controller.text);
    if (amount == null || amount <= 0) return;
    final newOutstanding = (loan.outstanding - amount).clamp(0, loan.amount);
    await repo.recordPayment(loan.id, amount, newOutstanding);
    key.currentState?.reload();
  }
}
