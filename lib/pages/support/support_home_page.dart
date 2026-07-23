import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/support.dart';
import '../../models/types.dart';
import '../../repositories/support_repository.dart';
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
  'open': BadgeTone.info,
  'in_progress': BadgeTone.warning,
  'resolved': BadgeTone.success,
  'closed': BadgeTone.neutral,
};

String _statusLabel(AppLocalizations l10n, String status) => switch (status) {
      'open' => l10n.supportStatusOpen,
      'in_progress' => l10n.supportStatusInProgress,
      'resolved' => l10n.supportStatusResolved,
      'closed' => l10n.supportStatusClosed,
      _ => status,
    };

class SupportHomePage extends StatelessWidget {
  const SupportHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    final isStaff = const {Role.crp, Role.clf, Role.admin}.contains(appState.user.role);
    final memberId = appState.profile?.id;
    final repo = SupportRepository();

    return Scaffold(
      appBar: PageHeader(title: l10n.supportHomeTitle),
      body: AppAsyncBuilder<List<SupportTicket>>(
        future: () => repo.fetchTickets(memberId: memberId, isStaff: isStaff),
        builder: (context, tickets) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconTile(onTap: () => context.go(Paths.supportChat), icon: Icons.forum_rounded, label: l10n.supportHomeMyTickets, tone: TileTone.brand),
                  IconTile(onTap: () => context.go(Paths.supportTicket), icon: Icons.add_comment_rounded, label: l10n.supportHomeRaiseTicket, tone: TileTone.gold),
                  IconTile(onTap: () => context.go(Paths.supportVoice), icon: Icons.mic_rounded, label: l10n.supportHomeVoiceHelp, tone: TileTone.sky),
                  IconTile(onTap: () => context.go(Paths.supportFaq), icon: Icons.help_rounded, label: l10n.supportHomeFaqs, tone: TileTone.violet),
                ],
              ),
              const SizedBox(height: 20),
              SectionHeader(title: isStaff ? l10n.supportHomeAllTickets : l10n.supportHomeMyTickets, action: l10n.supportHomeViewAll, onAction: () => context.go(Paths.supportChat)),
              if (tickets.isEmpty)
                AppEmptyState(icon: Icons.support_agent_rounded, message: l10n.supportHomeEmptyMessage)
              else
                ...tickets.take(5).map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        onTap: () => context.go(Paths.supportTicketDetail(t.id)),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.subject, style: AppTheme.sans(13, weight: FontWeight.w700)),
                                  if (isStaff && t.memberName != null) ...[
                                    const SizedBox(height: 2),
                                    Text(t.memberName!, style: AppTheme.sans(11, color: Neutral.c500)),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(DateFormat('dd MMM yyyy').format(t.createdAt), style: AppTheme.sans(11, color: Neutral.c400)),
                                ],
                              ),
                            ),
                            Flexible(child: AppBadge(text: _statusLabel(l10n, t.status), tone: _statusTones[t.status] ?? BadgeTone.neutral)),
                          ],
                        ),
                      ),
                    )),
            ],
          );
        },
      ),
    );
  }
}
