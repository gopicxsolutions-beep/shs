import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../models/scheme.dart';
import '../../models/types.dart';
import '../../repositories/scheme_repository.dart';
import '../../routes/paths.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/section_header.dart';

const _statusTones = <String, BadgeTone>{
  'applied': BadgeTone.warning,
  'under_review': BadgeTone.info,
  'approved': BadgeTone.success,
  'rejected': BadgeTone.danger,
};

class _SchemesData {
  final List<Scheme> schemes;
  final Map<String, SchemeApplication> applications;
  const _SchemesData(this.schemes, this.applications);
}

class SchemesHomePage extends StatelessWidget {
  const SchemesHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final repo = SchemeRepository();
    final memberId = appState.profile?.id;
    final isStaff = const {Role.crp, Role.clf, Role.admin}.contains(appState.user.role);

    return Scaffold(
      appBar: const PageHeader(title: 'Government Schemes'),
      body: AppAsyncBuilder<_SchemesData>(
        future: () async {
          final schemes = await repo.fetchSchemes();
          final apps = await repo.fetchMyApplications(memberId);
          return _SchemesData(schemes, apps);
        },
        builder: (context, data) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconTile(onTap: () => context.go(Paths.schemeEligibility), icon: Icons.fact_check_rounded, label: 'Eligibility', tone: TileTone.brand),
                  IconTile(onTap: () => context.go(Paths.schemeTracking), icon: Icons.timeline_rounded, label: 'Tracking', tone: TileTone.gold),
                  if (isStaff) IconTile(onTap: () => context.go(Paths.schemeApplications), icon: Icons.rule_folder_rounded, label: 'Applications', tone: TileTone.sky),
                ],
              ),
              const SizedBox(height: 20),
              const SectionHeader(title: 'All Schemes'),
              if (data.schemes.isEmpty)
                const AppEmptyState(icon: Icons.shield_rounded, message: 'No schemes available right now')
              else
                ...data.schemes.map((s) {
                  final app = data.applications[s.id];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      onTap: () => context.go(Paths.schemeDetail(s.id)),
                      child: Row(children: [
                        Container(width: 40, height: 40, decoration: BoxDecoration(color: Brand.c50, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.shield_rounded, color: Brand.c600, size: 20)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.name, style: AppTheme.sans(14, weight: FontWeight.w700)),
                              Text(s.agency ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(11, color: Neutral.c500)),
                            ],
                          ),
                        ),
                        Flexible(child: AppBadge(text: app?.status ?? 'not applied', tone: app != null ? (_statusTones[app.status] ?? BadgeTone.neutral) : BadgeTone.neutral)),
                      ]),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
