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

class AdminMonitoringPage extends StatefulWidget {
  const AdminMonitoringPage({super.key});
  @override
  State<AdminMonitoringPage> createState() => _AdminMonitoringPageState();
}

class _AdminMonitoringPageState extends State<AdminMonitoringPage> {
  final _repo = AdminRepository();
  final GlobalKey<AppAsyncBuilderState<_MonitoringData>> _key = GlobalKey();

  Future<_MonitoringData> _load(AdminRepository repo) async {
    final results = await Future.wait([repo.fetchSystemHealth(), repo.fetchAiAdvisorModerationStats()]);
    return _MonitoringData(health: results[0] as SystemHealth, moderation: results[1] as AiAdvisorModerationStats);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: PageHeader(
        title: l10n.adminMonitoringTitle,
        // Before this fix, the only way to see updated counts was to
        // navigate away and back — no pull-to-refresh, no reload button,
        // unlike FinancialLedgerPage's identical GlobalKey+IconButton
        // pattern this mirrors.
        right: IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: l10n.adminMonitoringRefreshTooltip, onPressed: () => _key.currentState?.reload()),
      ),
      body: AppAsyncBuilder<_MonitoringData>(
        key: _key,
        future: () => _load(_repo),
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
              // Real infra metrics from `system-health-check` (an actual
              // synthetic database round-trip, logged and aggregated over a
              // rolling 24h window — see that function's own header comment
              // for the honest scope). Every field is nullable: a demo-mode
              // session or a live call that couldn't reach the function both
              // render "—" here rather than a fabricated reading — see
              // AdminRepository.fetchSystemHealth()'s doc comment.
              Row(children: [
                Expanded(
                  child: StatCard(
                    label: l10n.adminMonitoringUptimeLabel,
                    value: h.uptimePercent24h != null ? '${h.uptimePercent24h!.toStringAsFixed(1)}%' : '—',
                    tone: h.uptimePercent24h == null
                        ? StatTone.ink
                        : h.uptimePercent24h! >= 99
                            ? StatTone.brand
                            : StatTone.danger,
                    icon: Icons.monitor_heart_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: l10n.adminMonitoringAvgLatencyLabel,
                    value: h.avgLatencyMs24h != null ? '${h.avgLatencyMs24h}ms' : '—',
                    tone: StatTone.ink,
                    icon: Icons.speed_rounded,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: StatCard(
                    label: l10n.adminMonitoringErrorRateLabel,
                    value: h.errorRatePercent24h != null ? '${h.errorRatePercent24h!.toStringAsFixed(2)}%' : '—',
                    tone: h.errorRatePercent24h == null
                        ? StatTone.ink
                        : h.errorRatePercent24h! > 0
                            ? StatTone.danger
                            : StatTone.brand,
                    icon: Icons.error_outline_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: l10n.adminMonitoringScheduledJobsLabel,
                    value: h.heartbeatHealthy == null ? '—' : (h.heartbeatHealthy! ? l10n.adminMonitoringScheduledJobsHealthy : l10n.adminMonitoringScheduledJobsUnhealthy),
                    tone: h.heartbeatHealthy == null
                        ? StatTone.ink
                        : h.heartbeatHealthy!
                            ? StatTone.brand
                            : StatTone.danger,
                    icon: Icons.schedule_rounded,
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
                      Expanded(child: Text(l10n.adminMonitoringScopeLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600))),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      l10n.adminMonitoringScopeDescription,
                      style: AppTheme.sans(12, color: Neutral.c500),
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.adminMonitoringCheckedAt(DateFormat('dd MMM yyyy, hh:mm a').format(h.checkedAt)), style: AppTheme.sans(11, color: Neutral.c400)),
                    // `totalChecks24h` was already fetched into `SystemHealth`
                    // but never rendered anywhere — the one figure that would
                    // reveal a dead cron schedule (expected ~12/hr; a much
                    // lower count means the check itself has stopped running,
                    // not that everything is healthy) was silently discarded
                    // (gap-hunt iteration 36).
                    if (h.totalChecks24h != null) Text(l10n.adminMonitoringChecksCount24h(h.totalChecks24h!), style: AppTheme.sans(11, color: Neutral.c400)),
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
