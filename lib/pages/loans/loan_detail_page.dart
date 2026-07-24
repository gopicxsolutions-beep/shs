import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/loan.dart';
import '../../models/types.dart';
import '../../repositories/loan_repository.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
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
  final _paymentsKey = GlobalKey<AppAsyncBuilderState<List<LoanPayment>>>();

  @override
  Widget build(BuildContext context) {
    // `loans_update_leader_or_staff` (RLS) only lets the SHG's leader or
    // staff update a loan row — recording a payment updates `outstanding`,
    // so a member recording a payment on their own loan would insert the
    // payment row (allowed) but silently fail to update the balance (RLS-
    // denied, no error surfaced), leaving the loan looking unpaid despite a
    // "successful" confirmation. Real SHG practice also has the leader/
    // treasurer record EMI payments collected at meetings, not the member
    // themselves — so this gates the button to match both the backend
    // permission model and the real workflow, rather than loosening RLS.
    final canRecordPayment = context.watch<AppState>().user.role != Role.member;
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
                    Text('₹${NumberFormat('#,##,##0', 'en_IN').format(loan.outstanding)}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text('outstanding of ₹${NumberFormat('#,##,##0', 'en_IN').format(loan.amount)}', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                    const SizedBox(height: 12),
                    AppProgressBar(value: paid, max: loan.amount, tone: ProgressTone.info),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _infoTile('EMI', '₹${NumberFormat('#,##,##0', 'en_IN').format(loan.emi)}')),
                const SizedBox(width: 12),
                Expanded(child: _infoTile('Tenure', '${loan.tenureMonths} months')),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _infoTile('Disbursed', loan.disbursedOn != null ? DateFormat('dd MMM yyyy').format(loan.disbursedOn!) : '—')),
                const SizedBox(width: 12),
                Expanded(child: _infoTile('Next Due', loan.nextDueDate != null ? DateFormat('dd MMM yyyy').format(loan.nextDueDate!) : '—')),
              ]),
              if (canRecordPayment && (loan.status == 'active' || loan.status == 'overdue')) ...[
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
                key: _paymentsKey,
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
                            Text('₹${NumberFormat('#,##,##0', 'en_IN').format(p.amount)}', style: AppTheme.sans(13, weight: FontWeight.w700, color: Brand.c600)),
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
                decoration: const InputDecoration(prefixText: '₹', labelText: 'Payment amount', counterText: ''),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: submitting ? null : () => Navigator.of(context).pop(false), child: Text(AppLocalizations.of(context)?.actionCancel ?? 'Cancel')),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      final amount = num.tryParse(controller.text);
                      if (amount == null || amount <= 0) {
                        setState(() => error = 'Enter a valid amount');
                        return;
                      }
                      // The RPC/demo-mode fallback both clamp `outstanding`
                      // to a floor of 0, so an overpayment can't push the
                      // balance negative — but without this check it would
                      // still silently accept e.g. a ₹50,000 payment against
                      // a ₹500 remaining balance, recording a payment amount
                      // that doesn't reconcile with what was actually owed
                      // (the payment history total would exceed loan.amount
                      // even though `outstanding` reads 0/closed).
                      if (amount > loan.outstanding) {
                        setState(() => error = 'Amount exceeds the outstanding balance of ₹${NumberFormat('#,##,##0', 'en_IN').format(loan.outstanding)}');
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
      _paymentsKey.currentState?.reload();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(SupabaseService.isConfigured ? 'Payment recorded' : 'Demo mode — not saved (connect Supabase to persist)')),
        );
      }
    }
  }
}
