import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/analytics.dart';
import '../../routes/paths.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_card.dart';

class CLFDashboard extends StatelessWidget {
  const CLFDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Transform.translate(
          offset: const Offset(0, -40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: StatCard(label: 'Village Orgs', value: '${villageWiseSHGs.length}', tone: StatTone.brand, trend: '${Kpis.totalSHGs} SHGs total', icon: Icons.apartment_rounded)),
              const SizedBox(width: 12),
              Expanded(child: StatCard(label: 'Total Savings', value: '₹${(Kpis.totalSavings / 10000000).toStringAsFixed(2)}Cr', tone: StatTone.gold, trend: 'Financial oversight', icon: Icons.savings_rounded)),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: AppCard(
            onTap: () => context.go(Paths.analyticsShgList),
            child: Row(children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: Brand.c50, borderRadius: BorderRadius.circular(16)), child: Icon(Icons.apartment_rounded, color: Brand.c600, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Monitor Village Organisations', style: AppTheme.sans(14, weight: FontWeight.w700)),
                Text('${villageWiseSHGs.length} villages · ${Kpis.totalSHGs} SHGs', style: AppTheme.sans(12, color: Neutral.c500)),
              ])),
              Icon(Icons.chevron_right, color: Neutral.c300),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeader(title: 'Village-wise SHGs', action: 'Federation reports', onAction: () => context.go(Paths.reportsFederation)),
            AppCard(
              child: SizedBox(
                height: 160,
                child: BarChart(
                  BarChartData(
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i < 0 || i >= villageWiseSHGs.length) return const SizedBox();
                        return Padding(padding: const EdgeInsets.only(top: 6), child: Text(villageWiseSHGs[i].village, style: AppTheme.sans(9, color: Neutral.c500)));
                      })),
                    ),
                    barGroups: [
                      for (var i = 0; i < villageWiseSHGs.length; i++)
                        BarChartGroupData(x: i, barRods: [BarChartRodData(toY: villageWiseSHGs[i].shgs.toDouble(), color: Brand.c500, width: 18, borderRadius: BorderRadius.circular(6))]),
                    ],
                  ),
                ),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeader(title: 'Financial Oversight'),
            Row(children: [
              Expanded(
                child: AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Loans Disbursed', style: AppTheme.sans(12, color: Neutral.c500)),
                    const SizedBox(height: 4),
                    Text('₹${(Kpis.loansDisbursed / 10000000).toStringAsFixed(2)}Cr', style: AppTheme.display(16)),
                  ]),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Recovery Rate', style: AppTheme.sans(12, color: Neutral.c500)),
                    const SizedBox(height: 4),
                    Text('${Kpis.recoveryRate}%', style: AppTheme.display(16, color: Brand.c700)),
                  ]),
                ),
              ),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: AppCard(
            onTap: () => context.go(Paths.analytics),
            gradient: const LinearGradient(colors: [Brand.c700, Brand.c600]),
            child: Row(children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.show_chart_rounded, color: Colors.white, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Full Analytics Dashboard', style: AppTheme.sans(14, weight: FontWeight.w700, color: Colors.white)),
                Text('KPIs, trends & recovery insights', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
              ])),
              const Text('Open', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
          ),
        ),
      ],
    );
  }
}
