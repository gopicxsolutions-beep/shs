import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../models/payment.dart';
import '../../repositories/payment_repository.dart';
import '../../routes/paths.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/section_header.dart';

const _statusTones = <String, BadgeTone>{
  'success': BadgeTone.success,
  'pending': BadgeTone.warning,
  'failed': BadgeTone.danger,
};

class PaymentsHomePage extends StatelessWidget {
  const PaymentsHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final repo = PaymentRepository();
    final memberId = appState.profile?.id;

    return Scaffold(
      appBar: const PageHeader(title: 'Digital Payments'),
      body: AppAsyncBuilder<List<Payment>>(
        future: () => repo.fetchHistory(memberId),
        builder: (context, payments) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconTile(onTap: () => context.go(Paths.paymentsQr), icon: Icons.qr_code_scanner_rounded, label: 'Scan & Pay', tone: TileTone.brand),
                  IconTile(onTap: () => context.go(Paths.paymentsHistory), icon: Icons.history_rounded, label: 'History', tone: TileTone.gold),
                ],
              ),
              const SizedBox(height: 20),
              SectionHeader(title: 'Recent Payments', action: 'View all', onAction: () => context.go(Paths.paymentsHistory)),
              if (payments.isEmpty)
                const AppEmptyState(icon: Icons.payments_rounded, message: 'No payments yet')
              else
                AppCard(
                  padded: false,
                  child: Column(
                    children: payments.take(5).map((p) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(children: [
                            Container(width: 32, height: 32, decoration: BoxDecoration(color: Brand.c50, borderRadius: BorderRadius.circular(10)), alignment: Alignment.center, child: Icon(Icons.qr_code_rounded, size: 16, color: Brand.c600)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${p.mode} · ${DateFormat('dd MMM yyyy').format(p.createdAt)}', style: AppTheme.sans(12, weight: FontWeight.w600)),
                                  if (p.reference != null) Text(p.reference!, style: AppTheme.sans(10, color: Neutral.c400)),
                                ],
                              ),
                            ),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text('₹${NumberFormat('#,##,##0', 'en_IN').format(p.amount)}', style: AppTheme.sans(13, weight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              AppBadge(text: p.status, tone: _statusTones[p.status] ?? BadgeTone.neutral),
                            ]),
                          ]),
                        )).toList(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
