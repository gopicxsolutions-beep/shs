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

const _statusFilters = ['open', 'in_progress', 'resolved', 'closed'];

String _statusLabel(AppLocalizations l10n, String status) => switch (status) {
      'open' => l10n.supportStatusOpen,
      'in_progress' => l10n.supportStatusInProgress,
      'resolved' => l10n.supportStatusResolved,
      'closed' => l10n.supportStatusClosed,
      _ => status,
    };

/// Full ticket list ("Chat Support") — every conversation the member has
/// raised, or (for staff) every ticket across all members.
///
/// Round 188: staff also get a search box (subject/member name) and a
/// status filter row — previously the identical flat, unfiltered ≤500-row
/// list was rendered for staff and member alike, with no way to triage a
/// growing platform-wide queue. Purely client-side over the already-
/// fetched list (no new repository call/RPC needed) — the existing fetch
/// already returns every ticket for staff in one call.
class SupportChatPage extends StatefulWidget {
  const SupportChatPage({super.key});
  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends State<SupportChatPage> {
  final _search = TextEditingController();
  String? _statusFilter;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<SupportTicket> _filtered(List<SupportTicket> tickets, bool isStaff) {
    if (!isStaff) return tickets;
    final query = _search.text.trim().toLowerCase();
    return tickets.where((t) {
      if (_statusFilter != null && t.status != _statusFilter) return false;
      if (query.isEmpty) return true;
      return t.subject.toLowerCase().contains(query) || (t.memberName?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

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
          final filtered = _filtered(tickets, isStaff);
          return Column(
            children: [
              if (isStaff && tickets.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        style: AppTheme.sans(13),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search_rounded, size: 18),
                          hintText: l10n.supportChatSearchHint,
                          filled: true,
                          fillColor: Neutral.c50,
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: Text(l10n.supportChatFilterAll),
                            selected: _statusFilter == null,
                            onSelected: (_) => setState(() => _statusFilter = null),
                          ),
                          ..._statusFilters.map((s) => ChoiceChip(
                                label: Text(_statusLabel(l10n, s)),
                                selected: _statusFilter == s,
                                onSelected: (_) => setState(() => _statusFilter = s),
                              )),
                        ],
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: filtered.isEmpty
                    ? AppEmptyState(icon: Icons.forum_rounded, message: l10n.supportChatEmptyMessage)
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final t = filtered[i];
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
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
