import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/admin.dart';
import '../../models/analytics.dart';
import '../../repositories/admin_repository.dart';
import '../../repositories/analytics_repository.dart';
import '../../routes/paths.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_card.dart';

/// A true uptime/error-rate/latency figure needs a real APM or
/// infra-monitoring service this codebase doesn't have wired up — same
/// documented gap as `SystemHealth` (see admin_monitoring_page.dart). Unlike
/// the Training Completion / pending-review / recent-activity figures below
/// (all real, computed — see [AdminRepository.fetchDashboardStats]), there is
/// no real table this one could ever be derived from, so it stays a
/// placeholder. Deliberately rendered as a neutral "N/A" — not a
/// fabricated-looking precise percentage like "99.98%" — because a
/// suspiciously precise number is exactly what a skimming user reads as
/// genuine telemetry, no matter how honest the much smaller/dimmer
/// "Not live-monitored" trend line underneath it is.
const _systemUptime = 'N/A';

const _activityTone = <AdminActivityKind, BadgeTone>{
  AdminActivityKind.newShg: BadgeTone.success,
  AdminActivityKind.newUser: BadgeTone.info,
  AdminActivityKind.document: BadgeTone.neutral,
};

/// "Xm/h/d ago" relative-time label for the Recent Activity feed — no
/// existing shared helper for this elsewhere in the app, so kept local to
/// this one feed rather than adding a new cross-cutting util for a single
/// caller.
String _relativeTime(AppLocalizations l10n, DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return l10n.adminDashboardJustNow;
  if (diff.inMinutes < 60) return l10n.adminDashboardMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l10n.adminDashboardHoursAgo(diff.inHours);
  if (diff.inDays < 30) return l10n.adminDashboardDaysAgo(diff.inDays);
  return l10n.adminDashboardMonthsAgo((diff.inDays / 30).floor());
}

/// Builds the Recent Activity feed's display sentence from [AdminActivityItem]'s
/// raw `kind` + `subjectName` — kept out of the repository layer (which has
/// no access to AppLocalizations) so this is real, localized text rather
/// than a hardcoded English string baked in server/repository-side.
String _activityMessage(AppLocalizations l10n, AdminActivityItem a) => switch (a.kind) {
  AdminActivityKind.newUser => l10n.adminDashboardActivityNewUser(a.subjectName),
  AdminActivityKind.newShg => l10n.adminDashboardActivityNewShg(a.subjectName),
  AdminActivityKind.document => l10n.adminDashboardActivityDocument(a.subjectName),
};

class _AdminDashboardData {
  final PlatformKpis kpis;
  final AdminDashboardStats stats;
  const _AdminDashboardData({required this.kpis, required this.stats});
}

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  Future<_AdminDashboardData> _load() async {
    final results = await Future.wait([
      AnalyticsRepository().fetchPlatformKpis(),
      AdminRepository().fetchDashboardStats(),
    ]);
    return _AdminDashboardData(kpis: results[0] as PlatformKpis, stats: results[1] as AdminDashboardStats);
  }

  @override
  Widget build(BuildContext context) {
    return AppAsyncBuilder<_AdminDashboardData>(
      future: _load,
      builder: (context, data) => _AdminDashboardBody(kpis: data.kpis, stats: data.stats),
    );
  }
}

class _AdminDashboardBody extends StatelessWidget {
  final PlatformKpis kpis;
  final AdminDashboardStats stats;
  const _AdminDashboardBody({required this.kpis, required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Transform.translate(
          offset: const Offset(0, -40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: StatCard(label: l10n.adminDashboardTotalShgsLabel, value: '${kpis.totalShgs}', tone: StatTone.brand, trend: l10n.adminDashboardActiveMembersTrend(kpis.activeMembers), icon: Icons.groups_rounded)),
              const SizedBox(width: 12),
              Expanded(child: StatCard(label: l10n.adminDashboardSystemUptimeLabel, value: _systemUptime, tone: StatTone.ink, trend: l10n.adminDashboardNotLiveMonitored, icon: Icons.dns_rounded)),
            ]),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -28),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                IconTile(onTap: () => context.go(Paths.adminUsers), icon: Icons.groups_rounded, label: l10n.adminDashboardUsersTile, tone: TileTone.brand),
                const SizedBox(width: 12),
                IconTile(onTap: () => context.go(Paths.adminShgs), icon: Icons.apartment_rounded, label: l10n.adminDashboardShgsTile, tone: TileTone.rose),
                const SizedBox(width: 12),
                IconTile(onTap: () => context.go(Paths.adminSchemes), icon: Icons.settings_suggest_rounded, label: l10n.adminDashboardSchemesTile, tone: TileTone.gold),
                const SizedBox(width: 12),
                IconTile(onTap: () => context.go(Paths.adminMonitoring), icon: Icons.dns_rounded, label: l10n.adminDashboardMonitoringTile, tone: TileTone.sky),
                const SizedBox(width: 12),
                IconTile(onTap: () => context.go(Paths.reportsFederation), icon: Icons.bar_chart_rounded, label: l10n.adminDashboardReportsTile, tone: TileTone.violet),
              ],
            ),
          ),
        ),
        // Real count of scheme_applications still awaiting a staff decision
        // (see AdminRepository.fetchDashboardStats) — replaces the old
        // fixed "3 accounts pending verification / Aadhaar e-KYC review"
        // banner, which named a KYC-review concept that doesn't exist
        // anywhere in this schema and never changed regardless of what
        // actually needed review. Hidden entirely rather than shown at "0
        // pending" when there's genuinely nothing to review.
        if (stats.pendingReviewCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: AppCard(
              color: Accent.amber50,
              borderColor: Accent.amber100,
              child: Row(children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(color: Accent.amber100, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.fact_check_rounded, color: Accent.amber600, size: 20)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l10n.adminDashboardPendingReviewCount(stats.pendingReviewCount), style: AppTheme.sans(13, weight: FontWeight.w700, color: Accent.amber800)),
                  Text(l10n.adminDashboardAwaitingReviewSubtitle, style: AppTheme.sans(12, color: Accent.amber600)),
                ])),
                Flexible(
                  child: InkWell(
                    onTap: () => context.go(Paths.schemeApplications),
                    child: Text(l10n.adminDashboardReviewAction, overflow: TextOverflow.ellipsis, style: AppTheme.sans(12, weight: FontWeight.w700, color: Accent.amber700)),
                  ),
                ),
              ]),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeader(title: l10n.adminDashboardPlatformSnapshotTitle, action: l10n.adminDashboardAnalyticsAction, onAction: () => context.go(Paths.analytics)),
            Row(children: [
              Expanded(
                child: AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l10n.adminDashboardLoansDisbursedLabel, style: AppTheme.sans(12, color: Neutral.c500)),
                    const SizedBox(height: 4),
                    Text('₹${(kpis.loansDisbursed / 10000000).toStringAsFixed(2)}Cr', style: AppTheme.display(16)),
                  ]),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l10n.adminDashboardTrainingCompletionLabel, style: AppTheme.sans(12, color: Neutral.c500)),
                    const SizedBox(height: 4),
                    Text('${stats.trainingCompletionPct}%', style: AppTheme.display(16, color: Brand.c700)),
                  ]),
                ),
              ),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeader(title: l10n.adminDashboardRecentActivityTitle),
            AppCard(
              padded: stats.recentActivity.isEmpty,
              child: stats.recentActivity.isEmpty
                  ? Text(l10n.adminDashboardNoRecentActivity, style: AppTheme.sans(12, color: Neutral.c400))
                  : Column(
                      children: stats.recentActivity.map((a) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Expanded(child: Text(_activityMessage(l10n, a), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(12, color: Neutral.c700))),
                              const SizedBox(width: 8),
                              Flexible(child: AppBadge(text: _relativeTime(l10n, a.occurredAt), tone: _activityTone[a.kind] ?? BadgeTone.neutral)),
                            ]),
                          )).toList(),
                    ),
            ),
          ]),
        ),
      ],
    );
  }
}
