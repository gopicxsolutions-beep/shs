import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/trend.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';

/// A small monthly line chart shared by the Analytics dashboard's 4 trend
/// charts and the Reports module's Federation "Savings Growth" / SHG
/// "Performance Report" attendance trend — one widget instead of
/// duplicating `fl_chart` boilerplate 5+ times.
class TrendChart extends StatelessWidget {
  final List<MonthlyPoint> points;
  final Color color;
  final String suffix;
  const TrendChart({super.key, required this.points, this.color = Brand.c500, this.suffix = ''});

  String get _semanticLabel {
    if (points.isEmpty) return 'Trend chart: no data';
    final parts = points.map((p) => '${p.month} ${p.value.toStringAsFixed(0)}$suffix').join(', ');
    final first = points.first.value;
    final last = points.last.value;
    final trend = first == 0 ? null : ((last - first) / first * 100);
    final trendText = trend == null ? '' : ', ${trend >= 0 ? 'up' : 'down'} ${trend.abs().toStringAsFixed(0)}% overall';
    return 'Trend chart: $parts$trendText';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _semanticLabel,
      child: ExcludeSemantics(
        child: SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= points.length) return const SizedBox();
                  return Padding(padding: const EdgeInsets.only(top: 6), child: Text(points[i].month, style: AppTheme.sans(9, color: Neutral.c500)));
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem('${s.y.toStringAsFixed(0)}$suffix', AppTheme.sans(11, weight: FontWeight.w700, color: Colors.white)))
                  .toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].value.toDouble())],
              isCurved: true,
              color: color,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.1)),
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }
}
