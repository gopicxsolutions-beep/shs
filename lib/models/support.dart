import '../l10n/gen/app_localizations.dart';

const supportCategories = ['general', 'savings', 'loans', 'meetings', 'livelihood', 'marketplace', 'payments', 'account', 'other'];
const supportPriorities = ['low', 'normal', 'high', 'urgent'];

String supportCategoryLabel(String category, AppLocalizations l10n) => switch (category) {
      'general' => l10n.supportCategoryGeneral,
      'savings' => l10n.supportCategorySavings,
      'loans' => l10n.supportCategoryLoans,
      'meetings' => l10n.supportCategoryMeetings,
      'livelihood' => l10n.supportCategoryLivelihood,
      'marketplace' => l10n.supportCategoryMarketplace,
      'payments' => l10n.supportCategoryPayments,
      'account' => l10n.supportCategoryAccount,
      'other' => l10n.supportCategoryOther,
      _ => category,
    };

String supportPriorityLabel(String priority, AppLocalizations l10n) => switch (priority) {
      'low' => l10n.supportPriorityLow,
      'normal' => l10n.supportPriorityNormal,
      'high' => l10n.supportPriorityHigh,
      'urgent' => l10n.supportPriorityUrgent,
      _ => priority,
    };

/// Mirrors a row in `public.support_tickets`, optionally joined with the
/// owning member's name (used in the staff-facing "all tickets" view).
class SupportTicket {
  final String id;
  final String memberId;
  final String? memberName;
  final String subject;
  final String? description;
  final String status; // open | in_progress | resolved | closed
  final String category; // general | savings | loans | meetings | livelihood | marketplace | payments | account | other
  final String priority; // low | normal | high | urgent
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? resolvedByName;
  final DateTime? resolvedAt;

  const SupportTicket({
    required this.id,
    required this.memberId,
    this.memberName,
    required this.subject,
    this.description,
    required this.status,
    this.category = 'general',
    this.priority = 'normal',
    required this.createdAt,
    DateTime? updatedAt,
    this.resolvedByName,
    this.resolvedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  factory SupportTicket.fromMap(Map<String, dynamic> map) => SupportTicket(
        id: map['id'] as String,
        memberId: map['member_id'] as String,
        memberName: (map['profiles'] as Map<String, dynamic>?)?['name'] as String?,
        subject: map['subject'] as String,
        description: map['description'] as String?,
        status: map['status'] as String,
        category: map['category'] as String? ?? 'general',
        priority: map['priority'] as String? ?? 'normal',
        // `created_at` is `timestamptz` (UTC). Convert to local (IST) here
        // so the date-only `DateFormat` calls in `support_home_page.dart`/
        // `support_chat_page.dart`/`support_ticket_detail_page.dart` never
        // show the wrong calendar day for a ticket filed near local
        // midnight.
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
        // `updated_at` (round 188) is now what the staff queue/member list
        // actually sorts by — a resolved ticket that gets a fresh reply
        // moves back to the top instead of staying buried at its original
        // creation-time position forever.
        updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String).toLocal() : null,
        resolvedByName: (map['resolved_by_profile'] as Map<String, dynamic>?)?['name'] as String?,
        resolvedAt: map['resolved_at'] != null ? DateTime.parse(map['resolved_at'] as String).toLocal() : null,
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
        // Same `timestamptz` → local conversion as `SupportTicket.createdAt`
        // above, for consistency (not currently date-formatted anywhere,
        // but keeps this field timezone-correct if it ever is).
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      );
}

/// A single frequently-asked question. FAQ content isn't backed by a table —
/// it's static reference content, hardcoded here.
class FaqEntry {
  final String question;
  final String answer;
  const FaqEntry({required this.question, required this.answer});
}
