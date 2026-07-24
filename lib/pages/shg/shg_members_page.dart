import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/shg.dart';
import '../../models/types.dart';
import '../../repositories/shg_repository.dart';
import '../../routes/paths.dart';
import '../../state/app_state.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/avatar.dart';
import '../../widgets/list_row.dart';

const _roleTones = <String, BadgeTone>{
  'leader': BadgeTone.gold,
  'crp': BadgeTone.info,
  'clf': BadgeTone.brand,
  'admin': BadgeTone.danger,
};

class ShgMembersPage extends StatelessWidget {
  const ShgMembersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final repo = ShgRepository();
    final shgId = appState.profile?.shgId;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: PageHeader(
        title: l10n.shgMembersTitle,
        right: appState.user.role == Role.leader
            ? IconButton(
                tooltip: l10n.shgMembersJoinRequestsTooltip,
                icon: Icon(Icons.person_add_alt_1_rounded, color: Brand.c600),
                onPressed: () => context.go(Paths.shgJoinRequests),
              )
            : null,
      ),
      body: AppAsyncBuilder<List<Member>>(
        future: () => repo.fetchMembers(shgId),
        builder: (context, members) {
          if (members.isEmpty) {
            return AppEmptyState(icon: Icons.groups_rounded, message: l10n.shgMembersEmpty);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: members.length,
            itemBuilder: (context, i) {
              final m = members[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padded: false,
                  child: AppListRow(
                    leading: AppAvatar(name: m.name, size: 36),
                    title: m.name,
                    subtitle: m.village ?? m.mobile ?? '',
                    trailing: m.role != 'member' ? AppBadge(text: m.role, tone: _roleTones[m.role] ?? BadgeTone.neutral) : null,
                    onTap: () => context.go(Paths.shgMember(m.id)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
