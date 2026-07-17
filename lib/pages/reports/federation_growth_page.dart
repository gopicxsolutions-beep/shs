import 'package:flutter/material.dart';
import '../../layout/page_header.dart';
import '../../models/trend.dart';
import '../../repositories/trend_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/trend_chart.dart';

class FederationGrowthPage extends StatelessWidget {
  const FederationGrowthPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = TrendRepository();

    return Scaffold(
      appBar: const PageHeader(title: 'Savings Growth'),
      body: AppAsyncBuilder<List<MonthlyPoint>>(
        future: repo.savingsTrend,
        builder: (context, points) {
          if (points.isEmpty) {
            return const AppEmptyState(icon: Icons.trending_up_rounded, message: 'No savings recorded yet');
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Monthly total savings across every SHG', style: AppTheme.sans(12, color: Neutral.c500)),
              const SizedBox(height: 12),
              AppCard(child: TrendChart(points: points, color: Brand.c500, suffix: '')),
            ],
          );
        },
      ),
    );
  }
}
