import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../layout/page_header.dart';
import '../../models/analytics.dart';
import '../../repositories/analytics_repository.dart';
import '../../routes/paths.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/progress_bar.dart';

const _gradeTone = <String, BadgeTone>{'A+': BadgeTone.success, 'A': BadgeTone.brand, 'B+': BadgeTone.brand, 'B': BadgeTone.warning, 'C': BadgeTone.danger};

class AnalyticsShgListPage extends StatelessWidget {
  const AnalyticsShgListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = AnalyticsRepository();

    return Scaffold(
      appBar: const PageHeader(title: 'SHGs Monitoring'),
      body: AppAsyncBuilder<List<ShgHealth>>(
        future: repo.fetchShgList,
        builder: (context, shgs) {
          if (shgs.isEmpty) {
            return const AppEmptyState(icon: Icons.apartment_rounded, message: 'No SHGs to monitor yet');
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: shgs.length,
            itemBuilder: (context, i) {
              final g = shgs[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  onTap: () => context.go(Paths.analyticsShgDetail(g.id)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(14, weight: FontWeight.w700)),
                              Text('${g.village} · ${g.memberCount} members', style: AppTheme.sans(12, color: Neutral.c500)),
                            ],
                          ),
                        ),
                        if (g.grade != null) AppBadge(text: g.grade!, tone: _gradeTone[g.grade] ?? BadgeTone.neutral),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: AppProgressBar(value: g.healthScore, tone: g.healthScore > 80 ? ProgressTone.brand : g.healthScore > 60 ? ProgressTone.gold : ProgressTone.danger)),
                        const SizedBox(width: 8),
                        Text('${g.healthScore.toStringAsFixed(0)}%', style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
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
}
