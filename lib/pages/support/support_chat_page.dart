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

/// Full ticket list ("Chat Support") — every conversation the member has
/// raised, or (for staff) every ticket across all members.
class SupportChatPage extends StatelessWidget {
  const SupportChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    final isStaff = const {Role.crp, Role.clf, Role.admin}.contains(appState.user.role);
    final memberId = appState.profile?.id;
    final repo = SupportRepository();

    return Scaffold(
      appBar: PageHeader(title: l10n.supportChatTitle),
      body: AppAsyncBuilder<List<SupportTicket>>(
        future: () => repo.fetchTickets(memberId: memberId, isStaff: isStaff),
        builder: (context, tickets) {
          if (tickets.isEmpty) {
            return AppEmptyState(icon: Icons.forum_rounded, message: l10n.supportChatEmptyMessage);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tickets.length,
            itemBuilder: (context, i) {
              final t = tickets[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  onTap: () => context.go(Paths.supportTicketDetail(t.id)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 36, height: 36, decoration: BoxDecoration(color: Brand.c50, borderRadius: BorderRadius.circular(10)), alignment: Alignment.center, child: Icon(Icons.chat_bubble_rounded, size: 16, color: Brand.c600)),
                      const SizedBox(width: 12),
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
              );
            },
          );
        },
      ),
    );
  }
}
