import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../models/support.dart';
import '../../models/types.dart';
import '../../repositories/support_repository.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/async_state.dart';

const _statusTones = <String, BadgeTone>{
  'open': BadgeTone.info,
  'in_progress': BadgeTone.warning,
  'resolved': BadgeTone.success,
  'closed': BadgeTone.neutral,
};
const _statuses = ['open', 'in_progress', 'resolved', 'closed'];

class SupportTicketDetailPage extends StatefulWidget {
  final String ticketId;
  const SupportTicketDetailPage({super.key, required this.ticketId});
  @override
  State<SupportTicketDetailPage> createState() => _SupportTicketDetailPageState();
}

class _SupportTicketDetailPageState extends State<SupportTicketDetailPage> {
  final _repo = SupportRepository();
  final _message = TextEditingController();
  final GlobalKey<AppAsyncBuilderState<_ThreadData>> _key = GlobalKey();
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<_ThreadData> _load() async {
    final ticket = await _repo.fetchTicket(widget.ticketId);
    final messages = await _repo.fetchMessages(widget.ticketId);
    return _ThreadData(ticket, messages);
  }

  Future<void> _send(String? memberId) async {
    if (_message.text.trim().isEmpty || !SupabaseService.isConfigured) return;
    setState(() => _sending = true);
    await _repo.sendMessage(ticketId: widget.ticketId, senderId: memberId, body: _message.text.trim());
    _message.clear();
    await _key.currentState?.reload();
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _changeStatus(String status) async {
    await _repo.updateStatus(widget.ticketId, status);
    _key.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isStaff = const {Role.crp, Role.clf, Role.admin}.contains(appState.user.role);
    final memberId = appState.profile?.id;

    return Scaffold(
      appBar: const PageHeader(title: 'Ticket'),
      body: AppAsyncBuilder<_ThreadData>(
        key: _key,
        future: _load,
        builder: (context, data) {
          final ticket = data.ticket;
          if (ticket == null) {
            return const AppEmptyState(icon: Icons.error_outline_rounded, message: 'This ticket could not be found');
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ticket.subject, style: AppTheme.display(15)),
                          const SizedBox(height: 2),
                          Text(DateFormat('dd MMM yyyy').format(ticket.createdAt), style: AppTheme.sans(11, color: Neutral.c500)),
                        ],
                      ),
                    ),
                    if (isStaff && SupabaseService.isConfigured)
                      PopupMenuButton<String>(
                        onSelected: _changeStatus,
                        itemBuilder: (context) => _statuses.map((s) => PopupMenuItem(value: s, child: Text(s.replaceAll('_', ' ')))).toList(),
                        child: AppBadge(text: ticket.status.replaceAll('_', ' '), tone: _statusTones[ticket.status] ?? BadgeTone.neutral),
                      )
                    else
                      AppBadge(text: ticket.status.replaceAll('_', ' '), tone: _statusTones[ticket.status] ?? BadgeTone.neutral),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: data.messages.isEmpty
                    ? const AppEmptyState(icon: Icons.chat_bubble_outline_rounded, message: 'No messages yet')
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: data.messages.length,
                        itemBuilder: (context, i) {
                          final m = data.messages[i];
                          final mine = SupabaseService.isConfigured ? m.senderId == memberId : m.senderId == 'me';
                          return Align(
                            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              constraints: const BoxConstraints(maxWidth: 280),
                              decoration: BoxDecoration(
                                color: mine ? Brand.c500 : Neutral.c100,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!mine && m.senderName != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Text(m.senderName!, style: AppTheme.sans(10, weight: FontWeight.w700, color: Neutral.c500)),
                                    ),
                                  Text(m.body, style: AppTheme.sans(13, color: mine ? Colors.white : Neutral.c700)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _message,
                        enabled: SupabaseService.isConfigured,
                        style: AppTheme.sans(13),
                        decoration: InputDecoration(
                          hintText: SupabaseService.isConfigured ? 'Type a message…' : 'Demo mode — replies disabled',
                          filled: true,
                          fillColor: Neutral.c50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.send_rounded, color: SupabaseService.isConfigured ? Brand.c600 : Neutral.c300),
                      onPressed: SupabaseService.isConfigured && !_sending ? () => _send(memberId) : null,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ThreadData {
  final SupportTicket? ticket;
  final List<SupportMessage> messages;
  const _ThreadData(this.ticket, this.messages);
}
