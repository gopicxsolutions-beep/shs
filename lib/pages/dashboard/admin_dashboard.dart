import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/analytics.dart';
import '../../routes/paths.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_card.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  static const _activity = [
    ('New SHG "Gayatri SHG" registered', '2h ago', BadgeTone.success),
    ('PMEGP scheme details updated', '5h ago', BadgeTone.info),
    ('Scheduled backup completed', '1d ago', BadgeTone.neutral),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Transform.translate(
          offset: const Offset(0, -40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: StatCard(label: 'Total SHGs', value: '${Kpis.totalSHGs}', tone: StatTone.brand, trend: '${Kpis.activeMembers} members', icon: Icons.groups_rounded)),
              const SizedBox(width: 12),
              Expanded(child: StatCard(label: 'System Uptime', value: '99.98%', tone: StatTone.ink, trend: 'All services normal', icon: Icons.dns_rounded)),
            ]),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconTile(onTap: () => context.go(Paths.adminUsers), icon: Icons.groups_rounded, label: 'Users', tone: TileTone.brand),
                IconTile(onTap: () => context.go(Paths.adminSchemes), icon: Icons.settings_suggest_rounded, label: 'Schemes', tone: TileTone.gold),
                IconTile(onTap: () => context.go(Paths.adminMonitoring), icon: Icons.dns_rounded, label: 'Monitoring', tone: TileTone.sky),
                IconTile(onTap: () => context.go(Paths.reportsFederation), icon: Icons.bar_chart_rounded, label: 'Reports', tone: TileTone.violet),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: AppCard(
            color: Accent.amber50,
            borderColor: Accent.amber100,
            child: Row(children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: Accent.amber100, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.shield_moon_rounded, color: Accent.amber600, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('3 accounts pending verification', style: AppTheme.sans(13, weight: FontWeight.w700, color: Accent.amber800)),
                Text('Aadhaar e-KYC review required', style: AppTheme.sans(12, color: Accent.amber600)),
              ])),
              InkWell(onTap: () => context.go(Paths.adminUsers), child: Text('Review', style: AppTheme.sans(12, weight: FontWeight.w700, color: Accent.amber700))),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeader(title: 'Platform Snapshot', action: 'Analytics', onAction: () => context.go(Paths.analytics)),
            Row(children: [
              Expanded(
                child: AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Loans Disbursed', style: AppTheme.sans(12, color: Neutral.c500)),
                    const SizedBox(height: 4),
                    Text('₹${(Kpis.loansDisbursed / 10000000).toStringAsFixed(2)}Cr', style: AppTheme.display(16)),
                  ]),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Training Completion', style: AppTheme.sans(12, color: Neutral.c500)),
                    const SizedBox(height: 4),
                    Text('${Kpis.trainingCompletion}%', style: AppTheme.display(16, color: Brand.c700)),
                  ]),
                ),
              ),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeader(title: 'Recent System Activity'),
            AppCard(
              padded: false,
              child: Column(
                children: _activity.map((a) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Expanded(child: Text(a.$1, style: AppTheme.sans(12, color: Neutral.c700))),
                        AppBadge(text: a.$2, tone: a.$3),
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
