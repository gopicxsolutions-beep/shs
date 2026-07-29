import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/report.dart';
import '../../models/trend.dart';
import '../../repositories/report_repository.dart';
import '../../repositories/shg_repository.dart';
import '../../repositories/trend_repository.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/trend_chart.dart';

class _PerformanceData {
  final ShgReportData report;
  final List<MonthlyPoint> attendanceTrend;
  const _PerformanceData(this.report, this.attendanceTrend);
}

class ShgPerformanceReportPage extends StatelessWidget {
  // Overrides the viewer's own SHG when provided — reached from
  // `AnalyticsShgDetailPage` (crp/clf/admin only), which already resolves a
  // specific SHG via `is_staff()`'s unrestricted read access. Omitted for a
  // leader viewing her own SHG's report, the page's original behavior.
  final String? shgId;
  final String? shgName;
  const ShgPerformanceReportPage({super.key, this.shgId, this.shgName});

  Future<_PerformanceData?> _load(String? shgId) async {
    if (shgId != null && !(await ShgRepository().shgExists(shgId))) return null;
    final reportRepo = ReportRepository();
    final trendRepo = TrendRepository();
    final report = await reportRepo.fetchShgReport(shgId);
    final attendanceTrend = await trendRepo.attendanceTrend(shgId: shgId);
    return _PerformanceData(report, attendanceTrend);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final resolvedShgId = shgId ?? context.watch<AppState>().profile?.shgId;

    return Scaffold(
      appBar: PageHeader(title: l10n.shgPerformanceReportTitle, subtitle: shgName),
      body: AppAsyncBuilder<_PerformanceData?>(
        future: () => _load(resolvedShgId),
        builder: (context, data) {
          if (data == null) {
            return AppEmptyState(icon: Icons.error_outline_rounded, message: l10n.shgReportShgNotFound);
          }
          final r = data.report;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(children: [
                Expanded(child: StatCard(label: l10n.shgPerformanceAvgAttendanceLabel, value: '${r.avgAttendancePct.toStringAsFixed(0)}%', tone: StatTone.brand, icon: Icons.event_available_rounded)),
                const SizedBox(width: 12),
                Expanded(child: StatCard(label: l10n.shgPerformanceActiveLoansLabel, value: '${r.activeLoanCount}', tone: StatTone.gold, icon: Icons.account_balance_rounded)),
              ]),
              const SizedBox(height: 16),
              Text(l10n.shgPerformanceAttendanceTrendLabel, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c500)),
              const SizedBox(height: 8),
              AppCard(
                child: data.attendanceTrend.isEmpty
                    ? Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Text(l10n.shgPerformanceEmptyTrend, style: AppTheme.sans(12, color: Neutral.c500))))
                    : TrendChart(points: data.attendanceTrend, color: Brand.c500, suffix: '%'),
              ),
            ],
          );
        },
      ),
    );
  }
}
