import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/support.dart' as mock;
import '../models/support.dart';
import '../services/supabase_service.dart';

/// Backed by `public.support_tickets` / `public.support_messages` when
/// Supabase is configured; falls back to `lib/data/support.dart` otherwise.
/// Tickets are private to the owning member, visible to staff (crp/clf/
/// admin) as well — mirrors the `support_tickets_select_self_or_staff` RLS
/// policy.
class SupportRepository {
  SupabaseClient get _client => SupabaseService.instance.client;
  bool get _live => SupabaseService.isConfigured;

  // Demo mode has no backing table, so a raised ticket would otherwise
  // vanish the instant the list reloads — track it here so it survives
  // for the rest of the session, mirroring AnnouncementRepository._locallyRead.
  static final List<SupportTicket> _locallyAdded = [];

  Future<List<SupportTicket>> fetchTickets({required String? memberId, required bool isStaff}) async {
    if (!_live || memberId == null) {
      final mockTickets = mock.mockTickets
          .map((t) => SupportTicket(id: t.id, memberId: memberId ?? 'me', subject: t.subject, description: t.description, status: t.status, createdAt: _parseMockDate(t.date)));
      return [..._locallyAdded.reversed, ...mockTickets];
    }
    var query = _client.from('support_tickets').select('*, profiles(name)');
    if (!isStaff) query = query.eq('member_id', memberId);
    final rows = await query.order('created_at', ascending: false);
    return (rows as List).map((r) => SupportTicket.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<SupportTicket?> fetchTicket(String id) async {
    if (!_live) {
      final local = _locallyAdded.where((t) => t.id == id);
      if (local.isNotEmpty) return local.first;
      final matches = mock.mockTickets.where((t) => t.id == id);
      if (matches.isEmpty) return null;
      final t = matches.first;
      return SupportTicket(id: t.id, memberId: 'me', subject: t.subject, description: t.description, status: t.status, createdAt: _parseMockDate(t.date));
    }
    final row = await _client.from('support_tickets').select('*, profiles(name)').eq('id', id).maybeSingle();
    if (row == null) return null;
    return SupportTicket.fromMap(row);
  }

  Future<List<SupportMessage>> fetchMessages(String ticketId) async {
    if (!_live) {
      return mock.mockMessages
          .where((m) => m.ticketId == ticketId)
          .map((m) => SupportMessage(id: '${m.ticketId}-${m.time}', ticketId: m.ticketId, senderId: m.sender == 'me' ? 'me' : null, senderName: m.sender == 'me' ? null : 'Support', body: m.body, createdAt: DateTime.now()))
          .toList();
    }
    final rows = await _client.from('support_messages').select('*, profiles(name)').eq('ticket_id', ticketId).order('created_at');
    return (rows as List).map((r) => SupportMessage.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Raises a new ticket and returns its id, so the caller can navigate
  /// straight into the chat thread.
  Future<String?> raiseTicket({required String? memberId, required String subject, required String description}) async {
    if (!_live) {
      final ticket = SupportTicket(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        memberId: memberId ?? 'me',
        subject: subject,
        description: description,
        status: 'open',
        createdAt: DateTime.now(),
      );
      _locallyAdded.add(ticket);
      return ticket.id;
    }
    final row = await _client.from('support_tickets').insert({
      'member_id': memberId,
      'subject': subject,
      'description': description,
    }).select().single();
    return row['id'] as String;
  }

  Future<void> sendMessage({required String ticketId, required String? senderId, required String body}) async {
    if (!_live || senderId == null) return;
    await _client.from('support_messages').insert({
      'ticket_id': ticketId,
      'sender_id': senderId,
      'body': body,
    });
  }

  Future<void> updateStatus(String ticketId, String status) async {
    if (!_live) return;
    await _client.from('support_tickets').update({'status': status}).eq('id', ticketId);
  }

  DateTime _parseMockDate(String s) {
    const months = {'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6, 'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12};
    try {
      final parts = s.split(' ');
      return DateTime(int.parse(parts[2]), months[parts[1]]!, int.parse(parts[0]));
    } catch (_) {
      return DateTime.now();
    }
  }
}
