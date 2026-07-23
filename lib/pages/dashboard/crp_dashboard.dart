import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/analytics.dart';
import '../../models/training.dart';
import '../../repositories/analytics_repository.dart';
import '../../repositories/training_repository.dart';
import '../../routes/paths.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/progress_bar.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_card.dart';

class _CrpDashboardData {
  final List<ShgHealth> shgs;
  final List<Course> courses;
  const _CrpDashboardData({required this.shgs, required this.courses});
}

class CRPDashboard extends StatelessWidget {
  const CRPDashboard({super.key});

  static const _gradeTone = <String, BadgeTone>{'A+': BadgeTone.success, 'A': BadgeTone.brand, 'B+': BadgeTone.brand, 'B': BadgeTone.warning, 'C': BadgeTone.danger};

  Future<_CrpDashboardData> _load() async {
    final results = await Future.wait([
      AnalyticsRepository().fetchShgList(),
      TrainingRepository().fetchCourses(),
    ]);
    return _CrpDashboardData(shgs: results[0] as List<ShgHealth>, courses: results[1] as List<Course>);
  }

  @override
  Widget build(BuildContext context) {
    return AppAsyncBuilder<_CrpDashboardData>(
      future: _load,
      builder: (context, data) => _CrpDashboardBody(data: data, gradeTone: _gradeTone),
    );
  }
}

class _CrpDashboardBody extends StatelessWidget {
  final _CrpDashboardData data;
  final Map<String, BadgeTone> gradeTone;
  const _CrpDashboardBody({required this.data, required this.gradeTone});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shgs = data.shgs;
    final avgHealth = shgs.isEmpty ? 0 : (shgs.map((g) => g.healthScore).reduce((a, b) => a + b) / shgs.length).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Transform.translate(
          offset: const Offset(0, -40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: StatCard(label: l10n.crpDashboardShgsMonitoredLabel, value: '${shgs.length}', tone: StatTone.brand, trend: shgs.isNotEmpty ? shgs.first.village : l10n.crpDashboardNoShgsYetTrend, icon: Icons.apartment_rounded)),
              const SizedBox(width: 12),
              Expanded(child: StatCard(label: l10n.crpDashboardAvgHealthScoreLabel, value: '$avgHealth%', tone: StatTone.gold, trend: l10n.crpDashboardAttendanceProxyTrend, icon: Icons.trending_up_rounded)),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeader(title: l10n.crpDashboardShgsUnderMonitoringTitle, action: l10n.crpDashboardViewAllAction, onAction: () => context.go(Paths.analyticsShgList)),
            if (shgs.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(l10n.crpDashboardNoShgsToMonitorYet, style: AppTheme.sans(12, color: Neutral.c400)))
            else
              // Capped like the Training Catalog preview below (`.take(3)`)
              // — this dashboard renders every card eagerly (it's a fixed
              // `Column` inside the page's `SingleChildScrollView`, not a
              // lazy `.builder`), and a CRP can realistically be assigned
              // 30+ SHGs across a federation (see the N+1 query fix in this
              // same file's history for that exact scale). Uncapped, every
              // login built a full `AppCard` (with its own progress bar,
              // badge, and multiple `Text`/`Row` children) for all of them
              // on the landing dashboard, most never scrolled into view.
              // The full, properly lazy `ListView.builder` list is one tap
              // away via "View all" (`AnalyticsShgListPage`).
              ...shgs.take(5).map((g) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      onTap: () => context.go(Paths.analyticsShgDetail(g.id)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(14, weight: FontWeight.w700)),
                            Text(l10n.crpDashboardShgVillageMembersSummary(g.village, g.memberCount), style: AppTheme.sans(12, color: Neutral.c500)),
                          ])),
                          AppBadge(text: g.grade ?? '—', tone: gradeTone[g.grade] ?? BadgeTone.neutral),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(child: AppProgressBar(value: g.healthScore, tone: g.healthScore > 80 ? ProgressTone.brand : g.healthScore > 60 ? ProgressTone.gold : ProgressTone.danger)),
                          const SizedBox(width: 8),
                          Text('${g.healthScore.round()}%', style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
                        ]),
                      ]),
                    ),
                  )),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeader(title: l10n.crpDashboardTrainingCatalogTitle, action: l10n.crpDashboardViewAllAction, onAction: () => context.go(Paths.training)),
            AppCard(
              padded: false,
              child: data.courses.isEmpty
                  ? Padding(padding: const EdgeInsets.all(16), child: Text(l10n.crpDashboardNoCoursesYet, style: AppTheme.sans(12, color: Neutral.c400)))
                  : Column(
                      children: data.courses.take(3).map((c) => InkWell(
                            onTap: () => context.go(Paths.trainingDetail(c.id)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(12, weight: FontWeight.w700)),
                                  Text(c.topic, style: AppTheme.sans(11, color: Neutral.c400)),
                                ])),
                                AppBadge(text: c.format, tone: BadgeTone.neutral),
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
