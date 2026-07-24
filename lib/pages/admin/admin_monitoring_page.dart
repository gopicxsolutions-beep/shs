import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/admin.dart';
import '../../repositories/admin_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/stat_card.dart';

class _MonitoringData {
  final SystemHealth health;
  final AiAdvisorModerationStats moderation;
  const _MonitoringData({required this.health, required this.moderation});
}

class AdminMonitoringPage extends StatelessWidget {
  const AdminMonitoringPage({super.key});

  Future<_MonitoringData> _load(AdminRepository repo) async {
    final results = await Future.wait([repo.fetchSystemHealth(), repo.fetchAiAdvisorModerationStats()]);
    return _MonitoringData(health: results[0] as SystemHealth, moderation: results[1] as AiAdvisorModerationStats);
  }

  @override
  Widget build(BuildContext context) {
    final repo = AdminRepository();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: PageHeader(title: l10n.adminMonitoringTitle),
      body: AppAsyncBuilder<_MonitoringData>(
        future: () => _load(repo),
        builder: (context, data) {
          final h = data.health;
          final moderation = data.moderation;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(children: [
                Expanded(child: StatCard(label: l10n.adminMonitoringTotalUsers, value: '${h.totalUsers}', tone: StatTone.brand, icon: Icons.people_rounded)),
                const SizedBox(width: 12),
                Expanded(child: StatCard(label: l10n.adminMonitoringTotalShgs, value: '${h.totalShgs}', tone: StatTone.ink, icon: Icons.apartment_rounded)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: StatCard(label: l10n.adminMonitoringSavingsEntries, value: '${h.totalSavingsEntries}', tone: StatTone.gold, icon: Icons.account_balance_wallet_rounded)),
                const SizedBox(width: 12),
                Expanded(child: StatCard(label: l10n.adminMonitoringLoansPending, value: '${h.totalLoans} (${h.pendingLoans})', tone: StatTone.danger, icon: Icons.account_balance_rounded)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: StatCard(
                    label: l10n.adminMonitoringAiModerationBlocksLabel,
                    value: '${moderation.blockedCount7d}',
                    tone: moderation.blockedCount7d > 0 ? StatTone.danger : StatTone.ink,
                    icon: Icons.shield_moon_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: l10n.adminMonitoringAiModerationMembersFlaggedLabel,
                    value: '${moderation.distinctMembersFlagged7d}',
                    tone: moderation.distinctMembersFlagged7d > 0 ? StatTone.danger : StatTone.ink,
                    icon: Icons.person_search_rounded,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.info_outline_rounded, size: 14, color: Neutral.c400),
                      const SizedBox(width: 6),
                      Expanded(child: Text(l10n.adminMonitoringPlaceholderLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600))),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      l10n.adminMonitoringPlaceholderDescription,
                      style: AppTheme.sans(12, color: Neutral.c500),
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.adminMonitoringCheckedAt(DateFormat('dd MMM yyyy, hh:mm a').format(h.checkedAt)), style: AppTheme.sans(11, color: Neutral.c400)),
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
