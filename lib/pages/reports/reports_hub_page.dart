import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../models/types.dart';
import '../../routes/paths.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/icon_tile.dart';

class ReportsHubPage extends StatelessWidget {
  const ReportsHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AppState>().user.role;
    final isLeaderOrStaff = role != Role.member;
    final isFederationStaff = const {Role.crp, Role.clf, Role.admin}.contains(role);

    return Scaffold(
      appBar: const PageHeader(title: 'Reports'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ReportCard(
            icon: Icons.person_rounded,
            tone: TileTone.brand,
            title: 'My Reports',
            subtitle: 'Your savings, loans & attendance summary',
            onTap: () => context.go(Paths.reportsMember),
          ),
          if (isLeaderOrStaff) ...[
            const SizedBox(height: 12),
            _ReportCard(
              icon: Icons.groups_rounded,
              tone: TileTone.gold,
              title: 'SHG Reports',
              subtitle: 'Group-wide savings, loans & attendance',
              onTap: () => context.go(Paths.reportsShg),
            ),
          ],
          if (isFederationStaff) ...[
            const SizedBox(height: 12),
            _ReportCard(
              icon: Icons.apartment_rounded,
              tone: TileTone.violet,
              title: 'Federation Reports',
              subtitle: 'Aggregated across every SHG',
              onTap: () => context.go(Paths.reportsFederation),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final IconData icon;
  final TileTone tone;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ReportCard({required this.icon, required this.tone, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      TileTone.brand => (Brand.c50, Brand.c600),
      TileTone.gold => (Gold.c50, Gold.c600),
      TileTone.violet => (Accent.violet50, Accent.violet600),
      TileTone.sky => (Accent.sky50, Accent.sky600),
      TileTone.rose => (Accent.rose50, Accent.rose600),
      TileTone.ink => (Neutral.c100, Neutral.c600),
    };
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)), alignment: Alignment.center, child: Icon(icon, size: 20, color: fg)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.sans(14, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTheme.sans(12, color: Neutral.c500)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Neutral.c300),
        ],
      ),
    );
  }
}
