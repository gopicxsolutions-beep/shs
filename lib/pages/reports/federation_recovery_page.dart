import 'package:flutter/material.dart';
import '../../layout/page_header.dart';
import '../../models/analytics.dart';
import '../../repositories/analytics_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/stat_card.dart';

class FederationRecoveryPage extends StatelessWidget {
  const FederationRecoveryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = AnalyticsRepository();

    return Scaffold(
      appBar: const PageHeader(title: 'Loan Recovery'),
      body: AppAsyncBuilder<PlatformKpis>(
        future: repo.fetchPlatformKpis,
        builder: (context, k) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(children: [
                Expanded(child: StatCard(label: 'Loans Disbursed', value: '₹${(k.loansDisbursed / 100000).toStringAsFixed(1)}L', tone: StatTone.brand, icon: Icons.account_balance_rounded)),
                const SizedBox(width: 12),
                Expanded(child: StatCard(label: 'Recovery Rate', value: '${k.recoveryRatePct.toStringAsFixed(1)}%', tone: StatTone.gold, icon: Icons.trending_up_rounded)),
              ]),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Recovered', style: AppTheme.sans(13, weight: FontWeight.w700)),
                      Text('${k.recoveryRatePct.toStringAsFixed(1)}%', style: AppTheme.sans(13, weight: FontWeight.w700, color: Brand.c600)),
                    ]),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(value: (k.recoveryRatePct / 100).clamp(0.0, 1.0), minHeight: 8, backgroundColor: Neutral.c100, color: Brand.c500),
                    ),
                    const SizedBox(height: 6),
                    Text('Across active, overdue & closed loans in every SHG', style: AppTheme.sans(11, color: Neutral.c500)),
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
