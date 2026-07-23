import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/analytics.dart';
import '../../repositories/analytics_repository.dart';
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
                      Text(l10n.analyticsShgDetailHealthScore, style: AppTheme.sans(13, weight: FontWeight.w700)),
                      Text('${g.healthScore.toStringAsFixed(0)}%', style: AppTheme.sans(13, weight: FontWeight.w700, color: Brand.c600)),
                    ]),
                    const SizedBox(height: 8),
                    AppProgressBar(value: g.healthScore, tone: g.healthScore > 80 ? ProgressTone.brand : g.healthScore > 60 ? ProgressTone.gold : ProgressTone.danger),
                    const SizedBox(height: 6),
                    Text(l10n.analyticsShgDetailHealthScoreNote, style: AppTheme.sans(11, color: Neutral.c500)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
