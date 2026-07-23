import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/analytics.dart';
import '../../models/report.dart';
import '../../repositories/analytics_repository.dart';
import '../../repositories/report_repository.dart';
import '../../routes/paths.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_card.dart';

class _ClfDashboardData {
  final PlatformKpis kpis;
  final List<VillageShgGroup> villages;
  const _ClfDashboardData({required this.kpis, required this.villages});
}

class CLFDashboard extends StatelessWidget {
  const CLFDashboard({super.key});

  Future<_ClfDashboardData> _load() async {
    final results = await Future.wait([
      AnalyticsRepository().fetchPlatformKpis(),
      ReportRepository().fetchVillageWiseShgs(),
    ]);
    return _ClfDashboardData(kpis: results[0] as PlatformKpis, villages: results[1] as List<VillageShgGroup>);
  }

  @override
  Widget build(BuildContext context) {
    return AppAsyncBuilder<_ClfDashboardData>(
      future: _load,
      builder: (context, data) => _ClfDashboardBody(data: data),
    );
  }
}

class _ClfDashboardBody extends StatelessWidget {
  final _ClfDashboardData data;
  const _ClfDashboardBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final kpis = data.kpis;
    final villages = data.villages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Transform.translate(
          offset: const Offset(0, -40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: StatCard(label: l10n.clfDashboardVillageOrgsLabel, value: '${villages.length}', tone: StatTone.brand, trend: l10n.clfDashboardShgsTotalTrend(kpis.totalShgs), icon: Icons.apartment_rounded)),
              const SizedBox(width: 12),
              Expanded(child: StatCard(label: l10n.clfDashboardTotalSavingsLabel, value: '₹${(kpis.totalSavings / 10000000).toStringAsFixed(2)}Cr', tone: StatTone.gold, trend: l10n.clfDashboardFinancialOversightTrend, icon: Icons.savings_rounded)),
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
                Text(l10n.clfDashboardMonitorVillageOrgsTitle, style: AppTheme.sans(14, weight: FontWeight.w700)),
                Text(l10n.clfDashboardVillagesShgsSummary(villages.length, kpis.totalShgs), style: AppTheme.sans(12, color: Neutral.c500)),
              ])),
              Icon(Icons.chevron_right, color: Neutral.c300),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeader(title: l10n.clfDashboardVillageWiseShgsTitle, action: l10n.clfDashboardFederationReportsAction, onAction: () => context.go(Paths.reportsFederation)),
            AppCard(
              child: villages.isEmpty
                  ? Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(l10n.clfDashboardNoVillagesYet, style: AppTheme.sans(12, color: Neutral.c400)))
                  : Semantics(
                      label: l10n.clfDashboardShgChartSemanticLabel(villages.map((v) => l10n.clfDashboardShgChartItemLabel(v.village, v.shgCount)).join(', ')),
                      child: ExcludeSemantics(
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
                                  if (i < 0 || i >= villages.length) return const SizedBox();
                                  return Padding(padding: const EdgeInsets.only(top: 6), child: Text(villages[i].village, style: AppTheme.sans(9, color: Neutral.c500)));
                                })),
                              ),
                              barGroups: [
                                for (var i = 0; i < villages.length; i++)
                                  BarChartGroupData(x: i, barRods: [BarChartRodData(toY: villages[i].shgCount.toDouble(), color: Brand.c500, width: 18, borderRadius: BorderRadius.circular(6))]),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeader(title: l10n.clfDashboardFinancialOversightTitle),
            Row(children: [
              Expanded(
                child: AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l10n.clfDashboardLoansDisbursedLabel, style: AppTheme.sans(12, color: Neutral.c500)),
                    const SizedBox(height: 4),
                    Text('₹${(kpis.loansDisbursed / 10000000).toStringAsFixed(2)}Cr', style: AppTheme.display(16)),
                  ]),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l10n.clfDashboardRecoveryRateLabel, style: AppTheme.sans(12, color: Neutral.c500)),
                    const SizedBox(height: 4),
                    Text('${kpis.recoveryRatePct.round()}%', style: AppTheme.display(16, color: Brand.c700)),
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
                Text(l10n.clfDashboardFullAnalyticsTitle, style: AppTheme.sans(14, weight: FontWeight.w700, color: Colors.white)),
                Text(l10n.clfDashboardFullAnalyticsSubtitle, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
              ])),
              Text(l10n.clfDashboardOpenAction, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
          ),
        ),
      ],
    );
  }
}
