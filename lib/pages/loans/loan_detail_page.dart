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
import '../../widgets/input_formatters.dart';
import '../../widgets/progress_bar.dart';
import '../../widgets/section_header.dart';

class LoanDetailPage extends StatefulWidget {
  final String loanId;
  const LoanDetailPage({super.key, required this.loanId});
  @override
  State<LoanDetailPage> createState() => _LoanDetailPageState();
}

class _LoanDetailPageState extends State<LoanDetailPage> {
  final _repo = LoanRepository();
  final _key = GlobalKey<AppAsyncBuilderState<Loan?>>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PageHeader(title: 'Loan Detail'),
      body: AppAsyncBuilder<Loan?>(
        key: _key,
        future: () => _repo.fetchById(widget.loanId),
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
                  onPressed: () => _recordPayment(context, loan),
                ),
              ],
              const SizedBox(height: 24),
              const SectionHeader(title: 'Payment History'),
              AppAsyncBuilder<List<LoanPayment>>(
                future: () => _repo.fetchPayments(widget.loanId),
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

  Future<void> _recordPayment(BuildContext context, Loan loan) async {
    final controller = TextEditingController(text: '${loan.emi}');
    String? error;
    var submitting = false;
    final recorded = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Record payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: decimalAmountInputFormatters,
                textInputAction: TextInputAction.done,
                maxLength: 7,
                decoration: const InputDecoration(prefixText: '₹', counterText: ''),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: submitting ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      final amount = num.tryParse(controller.text);
                      if (amount == null || amount <= 0) {
                        setState(() => error = 'Enter a valid amount');
                        return;
                      }
                      setState(() {
                        error = null;
                        submitting = true;
                      });
                      try {
                        final newOutstanding = (loan.outstanding - amount).clamp(0, loan.amount);
                        await _repo.recordPayment(loan.id, amount, newOutstanding);
                        if (context.mounted) Navigator.of(context).pop(true);
                      } catch (_) {
                        if (context.mounted) {
                          setState(() {
                            submitting = false;
                            error = 'Could not record this payment. Please try again.';
                          });
                        }
                      }
                    },
              child: Text(submitting ? 'Recording…' : 'Record'),
            ),
          ],
        ),
      ),
    );
    if (recorded == true) {
      _key.currentState?.reload();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(SupabaseService.isConfigured ? 'Payment recorded' : 'Demo mode — not saved (connect Supabase to persist)')),
        );
      }
    }
  }
}
