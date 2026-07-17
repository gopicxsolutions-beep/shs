import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../layout/page_header.dart';
import '../../models/analytics.dart';
import '../../repositories/analytics_repository.dart';
import '../../routes/paths.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/stat_card.dart';

class AnalyticsDashboardPage extends StatelessWidget {
  const AnalyticsDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = AnalyticsRepository();

    return Scaffold(
      appBar: const PageHeader(title: 'Analytics'),
      body: AppAsyncBuilder<PlatformKpis>(
        future: repo.fetchPlatformKpis,
        builder: (context, k) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(children: [
                Expanded(child: StatCard(label: 'Total SHGs', value: '${k.totalShgs}', tone: StatTone.brand, icon: Icons.apartment_rounded)),
                const SizedBox(width: 12),
                Expanded(child: StatCard(label: 'Active Members', value: '${k.activeMembers}', tone: StatTone.ink, icon: Icons.groups_rounded)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: StatCard(label: 'Total Savings', value: '₹${(k.totalSavings / 100000).toStringAsFixed(1)}L', tone: StatTone.gold, icon: Icons.account_balance_wallet_rounded)),
                const SizedBox(width: 12),
                Expanded(child: StatCard(label: 'Loans Disbursed', value: '₹${(k.loansDisbursed / 100000).toStringAsFixed(1)}L', tone: StatTone.brand, icon: Icons.account_balance_rounded)),
              ]),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Loan Recovery Rate', style: AppTheme.sans(13, weight: FontWeight.w700)),
                      Text('${k.recoveryRatePct.toStringAsFixed(1)}%', style: AppTheme.sans(13, weight: FontWeight.w700, color: Brand.c600)),
                    ]),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(value: (k.recoveryRatePct / 100).clamp(0.0, 1.0), minHeight: 8, backgroundColor: Neutral.c100, color: Brand.c500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                onTap: () => context.go(Paths.analyticsShgList),
                child: Row(children: [
                  Container(width: 44, height: 44, decoration: BoxDecoration(color: Brand.c50, borderRadius: BorderRadius.circular(14)), alignment: Alignment.center, child: Icon(Icons.apartment_rounded, size: 20, color: Brand.c600)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Monitor SHGs', style: AppTheme.sans(14, weight: FontWeight.w700)),
                        Text('Per-group health scores', style: AppTheme.sans(12, color: Neutral.c500)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: Neutral.c300),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}
