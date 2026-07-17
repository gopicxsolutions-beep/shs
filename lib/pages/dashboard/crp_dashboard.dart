import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/analytics.dart';
import '../../data/training.dart';
import '../../routes/paths.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/progress_bar.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_card.dart';

class CRPDashboard extends StatelessWidget {
  const CRPDashboard({super.key});

  static const _gradeTone = <String, BadgeTone>{'A+': BadgeTone.success, 'A': BadgeTone.brand, 'B+': BadgeTone.brand, 'B': BadgeTone.warning, 'C': BadgeTone.danger};

  @override
  Widget build(BuildContext context) {
    final avgHealth = (shgsForMonitoring.map((g) => g.health).reduce((a, b) => a + b) / shgsForMonitoring.length).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Transform.translate(
          offset: const Offset(0, -40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: StatCard(label: 'SHGs Monitored', value: '${shgsForMonitoring.length}', tone: StatTone.brand, trend: 'Kondapur cluster', icon: Icons.apartment_rounded)),
              const SizedBox(width: 12),
              Expanded(child: StatCard(label: 'Avg. Health Score', value: '$avgHealth%', tone: StatTone.gold, trend: '+4% this quarter', icon: Icons.trending_up_rounded)),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeader(title: 'SHGs Under Monitoring', action: 'View all', onAction: () => context.go(Paths.analyticsShgList)),
            ...shgsForMonitoring.map((g) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    onTap: () => context.go(Paths.analyticsShgDetail(g.id)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(14, weight: FontWeight.w700)),
                          Text('${g.village} · ${g.members} members', style: AppTheme.sans(12, color: Neutral.c500)),
                        ])),
                        AppBadge(text: g.grade, tone: _gradeTone[g.grade] ?? BadgeTone.neutral),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: AppProgressBar(value: g.health, tone: g.health > 80 ? ProgressTone.brand : g.health > 60 ? ProgressTone.gold : ProgressTone.danger)),
                        const SizedBox(width: 8),
                        Text('${g.health}%', style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
                      ]),
                    ]),
                  ),
                )),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeader(title: 'Training Updates', action: 'Manage', onAction: () => context.go(Paths.training)),
            AppCard(
              padded: false,
              child: Column(
                children: courses.take(3).map((c) => InkWell(
                      onTap: () => context.go(Paths.trainingDetail(c.id)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(12, weight: FontWeight.w700)),
                            Text(c.topic, style: AppTheme.sans(11, color: Neutral.c400)),
                          ])),
                          AppBadge(text: '${c.progress}%', tone: c.progress == 100 ? BadgeTone.success : BadgeTone.neutral),
                        ]),
                      ),
                    )).toList(),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}
