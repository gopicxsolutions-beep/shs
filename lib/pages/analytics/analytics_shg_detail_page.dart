import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../l10n/gen/app_localizations.dart';
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
import '../../widgets/stat_card.dart';

const _gradeTone = <String, BadgeTone>{'A+': BadgeTone.success, 'A': BadgeTone.brand, 'B+': BadgeTone.brand, 'B': BadgeTone.warning, 'C': BadgeTone.danger};

class AnalyticsShgDetailPage extends StatelessWidget {
  final String shgId;
  const AnalyticsShgDetailPage({super.key, required this.shgId});

  @override
  Widget build(BuildContext context) {
    final repo = AnalyticsRepository();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: PageHeader(title: l10n.analyticsShgDetailTitle),
      body: AppAsyncBuilder<ShgHealth?>(
        future: () => repo.fetchShgDetail(shgId),
        builder: (context, g) {
          if (g == null) {
            return AppEmptyState(icon: Icons.error_outline_rounded, message: l10n.analyticsShgDetailNotFound);
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.name, style: AppTheme.display(17)),
                        const SizedBox(height: 4),
                        Text(g.village, style: AppTheme.sans(12, color: Neutral.c500)),
                      ],
                    ),
                  ),
                  if (g.grade != null) AppBadge(text: g.grade!, tone: _gradeTone[g.grade] ?? BadgeTone.neutral),
                ]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: StatCard(label: l10n.analyticsShgDetailMembersLabel, value: '${g.memberCount}', tone: StatTone.ink, icon: Icons.groups_rounded)),
                const SizedBox(width: 12),
                Expanded(child: StatCard(label: l10n.analyticsShgDetailTotalSavings, value: '₹${NumberFormat('#,##,##0', 'en_IN').format(g.totalSavings)}', tone: StatTone.brand, icon: Icons.account_balance_wallet_rounded)),
              ]),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Flexible(child: Text(l10n.analyticsShgDetailHealthScore, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(13, weight: FontWeight.w700))),
                      const SizedBox(width: 8),
                      Text('${g.healthScore.toStringAsFixed(0)}%', style: AppTheme.sans(13, weight: FontWeight.w700, color: Brand.c600)),
                    ]),
                    const SizedBox(height: 8),
                    AppProgressBar(value: g.healthScore, tone: g.healthScore > 80 ? ProgressTone.brand : g.healthScore > 60 ? ProgressTone.gold : ProgressTone.danger),
                    const SizedBox(height: 6),
                    Text(l10n.analyticsShgDetailHealthScoreNote, style: AppTheme.sans(11, color: Neutral.c500)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // FR-RPT-2 (docs/SRS.md): the genuine platform-wide drill-down
              // this SHG's Financial Summary/Performance Report needed —
              // both pages already resolve any explicit shgId via the same
              // is_staff() RLS bypass this page's own fetchShgDetail() uses,
              // so this is a pure navigation addition, no repository change.
              _ReportLinkCard(
                icon: Icons.account_balance_wallet_rounded,
                title: l10n.shgReportsFinancialSummaryTitle,
                subtitle: l10n.shgReportsFinancialSummarySubtitle,
                onTap: () => context.go(Paths.analyticsShgFinancialSummary(shgId, name: g.name)),
              ),
              const SizedBox(height: 8),
              _ReportLinkCard(
                icon: Icons.trending_up_rounded,
                title: l10n.shgReportsPerformanceReportTitle,
                subtitle: l10n.shgReportsPerformanceReportSubtitle,
                onTap: () => context.go(Paths.analyticsShgPerformance(shgId, name: g.name)),
              ),
              const SizedBox(height: 8),
              // Same fix template, applied to `ShgMembersPage` — RLS
              // (`profiles_select_self_shg_or_staff`) is the same
              // unconditional `is_staff()` grant already used above, this
              // is again a pure navigation addition.
              _ReportLinkCard(
                icon: Icons.groups_rounded,
                title: l10n.analyticsShgDetailMembersLinkTitle,
                subtitle: l10n.analyticsShgDetailMembersLinkSubtitle,
                onTap: () => context.go(Paths.analyticsShgMembers(shgId, name: g.name)),
              ),
              const SizedBox(height: 8),
              // `approve_shg_join_request` (RLS) already authorizes
              // crp/clf/admin platform-wide — this was previously
              // undiscoverable from anywhere in the app (see
              // `ShgJoinRequestsPage`'s own doc comment), even though the
              // backend fully supported it.
              _ReportLinkCard(
                icon: Icons.person_add_alt_1_rounded,
                title: l10n.analyticsShgDetailJoinRequestsLinkTitle,
                subtitle: l10n.analyticsShgDetailJoinRequestsLinkSubtitle,
                onTap: () => context.go(Paths.analyticsShgJoinRequests(shgId, name: g.name)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReportLinkCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ReportLinkCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: Gold.c50, borderRadius: BorderRadius.circular(12)), alignment: Alignment.center, child: Icon(icon, size: 18, color: Gold.c600)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTheme.sans(13, weight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle, style: AppTheme.sans(11, color: Neutral.c500)),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: Neutral.c300),
      ]),
    );
  }
}
