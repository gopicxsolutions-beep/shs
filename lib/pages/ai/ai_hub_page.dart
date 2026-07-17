import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../layout/page_header.dart';
import '../../routes/paths.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/icon_tile.dart';

class AiHubPage extends StatelessWidget {
  const AiHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PageHeader(title: 'AI Advisors'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Ask an advisor', style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c500)),
          const SizedBox(height: 12),
          _AdvisorCard(
            icon: Icons.savings_rounded,
            tone: TileTone.brand,
            title: 'Financial Advisor',
            subtitle: 'Savings, loans & budgeting guidance',
            onTap: () => context.go(Paths.aiFinancialAdvisor),
          ),
          const SizedBox(height: 12),
          _AdvisorCard(
            icon: Icons.description_rounded,
            tone: TileTone.violet,
            title: 'Scheme Recommender',
            subtitle: 'Find government schemes you qualify for',
            onTap: () => context.go(Paths.aiSchemeRecommender),
          ),
          const SizedBox(height: 12),
          _AdvisorCard(
            icon: Icons.storefront_rounded,
            tone: TileTone.gold,
            title: 'Market Advisor',
            subtitle: 'Pricing & selling tips for your products',
            onTap: () => context.go(Paths.aiMarketAdvisor),
          ),
        ],
      ),
    );
  }
}

class _AdvisorCard extends StatelessWidget {
  final IconData icon;
  final TileTone tone;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _AdvisorCard({required this.icon, required this.tone, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      TileTone.brand => (Brand.c50, Brand.c600),
      TileTone.gold => (Gold.c50, Gold.c600),
      TileTone.sky => (Accent.sky50, Accent.sky600),
      TileTone.rose => (Accent.rose50, Accent.rose600),
      TileTone.violet => (Accent.violet50, Accent.violet600),
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
