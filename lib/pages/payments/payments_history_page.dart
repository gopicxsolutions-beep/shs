import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../models/payment.dart';
import '../../repositories/payment_repository.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/list_row.dart';

const _statusTones = <String, BadgeTone>{
  'success': BadgeTone.success,
  'pending': BadgeTone.warning,
  'failed': BadgeTone.danger,
};

class PaymentsHistoryPage extends StatelessWidget {
  const PaymentsHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final repo = PaymentRepository();
    final memberId = appState.profile?.id;

    return Scaffold(
      appBar: const PageHeader(title: 'Payment History'),
      body: AppAsyncBuilder<List<Payment>>(
        future: () => repo.fetchHistory(memberId),
        builder: (context, payments) {
          if (payments.isEmpty) {
            return const AppEmptyState(icon: Icons.receipt_long_rounded, message: 'No payments yet');
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: payments.length,
            itemBuilder: (context, i) {
              final p = payments[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padded: false,
                  child: AppListRow(
                    title: '${p.mode} Payment',
                    subtitle: '${p.reference ?? ''} · ${DateFormat('dd MMM yyyy').format(p.createdAt)}',
                    trailing: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('₹${NumberFormat('#,##,##0', 'en_IN').format(p.amount)}', style: AppTheme.sans(13, weight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        AppBadge(text: p.status, tone: _statusTones[p.status] ?? BadgeTone.neutral),
                      ],
                    ),
                    chevron: false,
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
