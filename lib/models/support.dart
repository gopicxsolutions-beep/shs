/// Mirrors a row in `public.support_tickets`, optionally joined with the
/// owning member's name (used in the staff-facing "all tickets" view).
class SupportTicket {
  final String id;
  final String memberId;
  final String? memberName;
  final String subject;
  final String? description;
  final String status; // open | in_progress | resolved | closed
  final DateTime createdAt;

  const SupportTicket({
    required this.id,
    required this.memberId,
    this.memberName,
    required this.subject,
    this.description,
    required this.status,
    required this.createdAt,
  });

  factory SupportTicket.fromMap(Map<String, dynamic> map) => SupportTicket(
        id: map['id'] as String,
        memberId: map['member_id'] as String,
        memberName: (map['profiles'] as Map<String, dynamic>?)?['name'] as String?,
        subject: map['subject'] as String,
        description: map['description'] as String?,
        status: map['status'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

/// Mirrors a row in `public.support_messages`.
class SupportMessage {
  final String id;
  final String ticketId;
  final String? senderId;
  final String? senderName;
  final String body;
  final DateTime createdAt;

  const SupportMessage({
    required this.id,
    required this.ticketId,
    this.senderId,
    this.senderName,
    required this.body,
    required this.createdAt,
  });

  factory SupportMessage.fromMap(Map<String, dynamic> map) => SupportMessage(
        id: map['id'] as String,
        ticketId: map['ticket_id'] as String,
        senderId: map['sender_id'] as String?,
        senderName: (map['profiles'] as Map<String, dynamic>?)?['name'] as String?,
        body: map['body'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

/// A single frequently-asked question. FAQ content isn't backed by a table —
/// it's static reference content, hardcoded here.
class FaqEntry {
  final String question;
  final String answer;
  const FaqEntry({required this.question, required this.answer});
}
