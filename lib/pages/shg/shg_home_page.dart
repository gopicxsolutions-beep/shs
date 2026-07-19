import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../models/shg.dart';
import '../../models/types.dart';
import '../../repositories/shg_repository.dart';
import '../../routes/paths.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/section_header.dart';

class ShgHomePage extends StatelessWidget {
  const ShgHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isLeaderOrStaff = appState.user.role != Role.member;
    final repo = ShgRepository();
    final shgId = appState.profile?.shgId;

    return Scaffold(
      appBar: const PageHeader(title: 'My SHG'),
      body: AppAsyncBuilder<ShgProfile?>(
        future: () => repo.fetchShg(shgId),
        builder: (context, shg) {
          if (shg == null) {
            return const AppEmptyState(icon: Icons.groups_rounded, message: "You're not linked to an SHG yet");
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                gradient: const LinearGradient(colors: [Brand.c700, Brand.c600]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Expanded(child: Text(shg.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white))),
                      if (shg.grade != null) AppBadge(text: shg.grade!, tone: BadgeTone.neutral),
                    ]),
                    const SizedBox(height: 4),
                    Text('${shg.village ?? ''}, ${shg.district ?? ''}', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                    if (shg.regNumber != null) ...[
                      const SizedBox(height: 8),
                      Text('Reg. ${shg.regNumber}', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconTile(onTap: () => context.go(Paths.shgMembers), icon: Icons.groups_rounded, label: 'Members', tone: TileTone.brand),
                  IconTile(onTap: () => context.go(Paths.shgDocuments), icon: Icons.folder_rounded, label: 'Documents', tone: TileTone.gold),
                ],
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Federation'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Soft hyphen gives the narrow label column a sensible
                    // break point instead of an arbitrary mid-word cut.
                    _row('Village Organi­sation', shg.vo ?? '—'),
                    const SizedBox(height: 8),
                    _row('CLF', shg.clf ?? '—'),
                    const SizedBox(height: 8),
                    _row('Mandal', shg.mandal ?? '—'),
                  ],
                ),
              ),
              if (isLeaderOrStaff) ...[
                const SizedBox(height: 20),
                const SectionHeader(title: 'Bank Details'),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row('Bank', shg.bankName ?? '—'),
                      const SizedBox(height: 8),
                      _row('Account', shg.bankAccount ?? '—'),
                      const SizedBox(height: 8),
                      _row('IFSC', shg.ifsc ?? '—'),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _row(String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: AppTheme.sans(12, color: Neutral.c500))),
          const SizedBox(width: 8),
          Text(value, style: AppTheme.sans(12, weight: FontWeight.w700), textAlign: TextAlign.right),
        ],
      );
}
