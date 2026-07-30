import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/analytics.dart';
import '../../models/paged_result.dart';
import '../../models/training.dart';
import '../../repositories/admin_repository.dart';
import '../../repositories/analytics_repository.dart';
import '../../repositories/shg_join_request_repository.dart';
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
  final int trainingCompletionPct;
  // The federation's TRUE total SHG count (from a real count query), not
  // `shgs.length` — see this class's own doc comment on `_load()` for why
  // those two used to silently diverge past 100 SHGs.
  final int totalShgs;
  final int pendingJoinRequests;
  const _CrpDashboardData({
    required this.shgs,
    required this.courses,
    required this.trainingCompletionPct,
    required this.totalShgs,
    required this.pendingJoinRequests,
  });
}

class CRPDashboard extends StatelessWidget {
  const CRPDashboard({super.key});

  static const _gradeTone = <String, BadgeTone>{'A+': BadgeTone.success, 'A': BadgeTone.brand, 'B+': BadgeTone.brand, 'B': BadgeTone.warning, 'C': BadgeTone.danger};

  // Round 135's SRS.md gap note: `AdminRepository.fetchTrainingCompletionPct()`
  // (`is_staff()` RLS bypass) has always been genuinely platform-wide, not
  // admin-only — only `admin_dashboard.dart` ever called it. Added here as
  // its own standalone stat rather than pulling in the admin dashboard's
  // bundled pendingReviewCount/recentActivity feed alongside it, matching
  // that gap note's own reasoning for what a CRP dashboard actually needs.
  Future<_CrpDashboardData> _load() async {
    final results = await Future.wait([
      AnalyticsRepository().fetchShgList(),
      TrainingRepository().fetchCourses(),
      AdminRepository().fetchTrainingCompletionPct(),
      // A real count, not derived from the paginated list below —
      // `fetchShgList()` only ever returns its first page (`pageSize:
      // 100` default), so "SHGs Monitored" used to silently show that
      // page's length as if it were the federation's total, truncating at
      // exactly 100 for any federation past that size with no indication
      // anything was cut off. `fetchPlatformKpis().totalShgs` already
      // exists (it's what the CLF dashboard's equivalent stat correctly
      // uses) and is a genuine, unbounded `count`, cheap even at scale
      // since it only selects `id`.
      AnalyticsRepository().fetchPlatformKpis(),
      // A federation-wide count so a new join request is immediately
      // visible here rather than only discoverable by drilling into one
      // SHG at a time via AnalyticsShgDetailPage's own link tile.
      ShgJoinRequestRepository().fetchPendingCountAcrossAllShgs(),
    ]);
    // Dashboard landing preview — first page only (same 100-row default as
    // AdminUsersPage's first page), same spirit as this page's own existing
    // "Recent activity" 5-row caps elsewhere in the app. The dedicated "SHG
    // list" screen (AnalyticsShgListPage) is where a CRP/CLF/Admin reaches
    // every SHG via Load More.
    final shgPage = results[0] as PagedResult<ShgHealth>;
    return _CrpDashboardData(
      shgs: shgPage.items,
      courses: results[1] as List<Course>,
      trainingCompletionPct: results[2] as int,
      totalShgs: (results[3] as PlatformKpis).totalShgs,
      pendingJoinRequests: results[4] as int,
    );
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
    // "Avg. Health Score" is only ever computed from the loaded preview
    // page (`shgs`, capped at 100) — a true federation-wide average would
    // need the same 4-query batching this page's own history already
    // fixed once for scaling reasons, run unbounded across every SHG,
    // reintroducing exactly the cost that fix was meant to avoid. Rather
    // than silently present a partial figure as the platform-wide truth
    // once a federation exceeds that page size, the trend label says so
    // explicitly whenever `data.totalShgs` (a real count) exceeds what was
    // actually averaged.
    final avgHealthIsPartial = data.totalShgs > shgs.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Transform.translate(
          offset: const Offset(0, -40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: StatCard(label: l10n.crpDashboardShgsMonitoredLabel, value: '${data.totalShgs}', tone: StatTone.brand, trend: shgs.isNotEmpty ? shgs.first.village : l10n.crpDashboardNoShgsYetTrend, icon: Icons.apartment_rounded)),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  label: l10n.crpDashboardAvgHealthScoreLabel,
                  value: '$avgHealth%',
                  tone: StatTone.gold,
                  trend: avgHealthIsPartial ? l10n.crpDashboardAvgHealthPartialTrend(shgs.length) : l10n.crpDashboardAttendanceProxyTrend,
                  icon: Icons.trending_up_rounded,
                ),
              ),
            ]),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: StatCard(
              label: l10n.crpDashboardTrainingCompletionLabel,
              value: '${data.trainingCompletionPct}%',
              tone: StatTone.ink,
              trend: l10n.crpDashboardTrainingCompletionTrend,
              icon: Icons.school_rounded,
            ),
          ),
        ),
        // Mirrors admin_dashboard.dart's pendingReviewCount banner (same
        // amber-card pattern) — hidden entirely at 0 rather than shown as
        // "0 pending", matching that precedent.
        if (data.pendingJoinRequests > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: AppCard(
              color: Accent.amber50,
              borderColor: Accent.amber100,
              child: Row(children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(color: Accent.amber100, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.person_add_alt_1_rounded, color: Accent.amber600, size: 20)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l10n.dashboardPendingJoinRequestsCount(data.pendingJoinRequests), style: AppTheme.sans(13, weight: FontWeight.w700, color: Accent.amber800)),
                  Text(l10n.dashboardPendingJoinRequestsSubtitle, style: AppTheme.sans(12, color: Accent.amber600)),
                ])),
                Flexible(
                  child: InkWell(
                    onTap: () => context.go(Paths.allShgJoinRequests),
                    child: Text(l10n.dashboardPendingJoinRequestsAction, overflow: TextOverflow.ellipsis, style: AppTheme.sans(12, weight: FontWeight.w700, color: Accent.amber700)),
                  ),
                ),
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
