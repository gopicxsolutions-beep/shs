import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../models/loan.dart';
import '../../repositories/loan_repository.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/avatar.dart';
import '../../widgets/input_formatters.dart';

class LoanApprovalPage extends StatelessWidget {
  const LoanApprovalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final repo = LoanRepository();
    final shgId = appState.profile?.shgId;
    final key = GlobalKey<AppAsyncBuilderState<List<Loan>>>();

    return Scaffold(
      appBar: const PageHeader(title: 'Loan Approvals'),
      body: AppAsyncBuilder<List<Loan>>(
        key: key,
        future: () => repo.fetchForShg(shgId),
        builder: (context, loans) {
          final pending = loans.where((l) => l.status == 'pending').toList();
          if (pending.isEmpty) {
            return const AppEmptyState(icon: Icons.fact_check_rounded, message: 'No pending loan applications');
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pending.length,
            itemBuilder: (context, i) {
              final l = pending[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        AppAvatar(name: l.memberName, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.memberName, style: AppTheme.sans(14, weight: FontWeight.w700)),
                              Text(l.purpose, style: AppTheme.sans(12, color: Neutral.c500)),
                            ],
                          ),
                        ),
                        Text('₹${l.amount}', style: AppTheme.display(16)),
                      ]),
                      const SizedBox(height: 4),
                      Text('${l.tenureMonths} month tenure', style: AppTheme.sans(11, color: Neutral.c400)),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: !SupabaseService.isConfigured
                                ? null
                                : () async {
                                    await repo.reject(l.id);
                                    key.currentState?.reload();
                                  },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Accent.red100),
                              foregroundColor: Accent.red600,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: !SupabaseService.isConfigured ? null : () => _approve(context, repo, l, key),
                            style: FilledButton.styleFrom(backgroundColor: Brand.c600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                            child: const Text('Approve'),
                          ),
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

  Future<void> _approve(BuildContext context, LoanRepository repo, Loan l, GlobalKey<AppAsyncBuilderState<List<Loan>>> key) async {
    final suggestedEmi = (l.amount / l.tenureMonths).ceil();
    final emiController = TextEditingController(text: '$suggestedEmi');
    String? error;
    var submitting = false;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Approve loan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Monthly EMI for ${l.memberName}', style: AppTheme.sans(12, color: Neutral.c500)),
              const SizedBox(height: 8),
              TextField(controller: emiController, keyboardType: TextInputType.number, inputFormatters: decimalAmountInputFormatters, decoration: const InputDecoration(prefixText: '₹')),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      final emi = num.tryParse(emiController.text);
                      if (emi == null || emi <= 0) {
                        setState(() => error = 'Enter a valid EMI amount');
                        return;
                      }
                      setState(() {
                        error = null;
                        submitting = true;
                      });
                      try {
                        await repo.approve(l.id, emi: emi, nextDueDate: DateTime.now().add(const Duration(days: 30)));
                        if (context.mounted) Navigator.of(context).pop(true);
                      } catch (_) {
                        setState(() {
                          submitting = false;
                          error = 'Could not approve this loan. Please try again.';
                        });
                      }
                    },
              child: Text(submitting ? 'Approving…' : 'Approve'),
            ),
          ],
        ),
      ),
    );
    if (approved == true) key.currentState?.reload();
  }
}
