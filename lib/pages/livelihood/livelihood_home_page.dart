import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../models/livelihood.dart';
import '../../models/types.dart';
import '../../repositories/livelihood_repository.dart';
import '../../routes/paths.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/avatar.dart';
import '../../widgets/stat_card.dart';

const _statusTones = <String, BadgeTone>{
  'planned': BadgeTone.neutral,
  'active': BadgeTone.brand,
  'completed': BadgeTone.success,
};

class LivelihoodHomePage extends StatelessWidget {
  const LivelihoodHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isLeaderOrStaff = appState.user.role != Role.member;
    final repo = LivelihoodRepository();
    final shgId = appState.profile?.shgId;
    final memberId = appState.profile?.id;

    return Scaffold(
      appBar: PageHeader(
        title: 'Livelihoods',
        right: IconButton(icon: const Icon(Icons.add_circle_rounded, color: Brand.c600), onPressed: () => context.go(Paths.livelihoodEntry), tooltip: 'Add activity'),
      ),
      body: AppAsyncBuilder<List<LivelihoodActivity>>(
        future: () => isLeaderOrStaff ? repo.fetchForShg(shgId) : repo.fetchForMember(memberId),
        builder: (context, activities) {
          final totalInvestment = activities.fold<num>(0, (s, a) => s + a.investment);
          final totalRevenue = activities.fold<num>(0, (s, a) => s + a.revenue);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Row(children: [
                Expanded(child: StatCard(label: 'Total Investment', value: '₹${NumberFormat('#,##0').format(totalInvestment)}', tone: StatTone.gold, icon: Icons.trending_up_rounded)),
                const SizedBox(width: 12),
                Expanded(child: StatCard(label: 'Total Revenue', value: '₹${NumberFormat('#,##0').format(totalRevenue)}', tone: StatTone.brand, icon: Icons.payments_rounded)),
              ]),
              const SizedBox(height: 20),
              if (activities.isEmpty)
                const AppEmptyState(icon: Icons.eco_rounded, message: 'No livelihood activities yet')
              else
                ...activities.map((a) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        onTap: () => context.go(Paths.livelihoodDetail(a.id)),
                        child: Row(children: [
                          if (isLeaderOrStaff) ...[AppAvatar(name: a.memberName, size: 36), const SizedBox(width: 12)],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.activityType, style: AppTheme.sans(14, weight: FontWeight.w700)),
                                Text(isLeaderOrStaff ? a.memberName : (a.description ?? ''), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(12, color: Neutral.c500)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              AppBadge(text: a.status, tone: _statusTones[a.status] ?? BadgeTone.neutral),
                              const SizedBox(height: 4),
                              Text('₹${a.revenue - a.investment} net', style: AppTheme.sans(11, color: a.profit >= 0 ? Brand.c600 : Accent.red600)),
                            ],
                          ),
                        ]),
                      ),
                    )),
            ],
          );
        },
      ),
    );
  }
}
