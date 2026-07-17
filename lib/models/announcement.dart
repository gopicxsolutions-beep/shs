/// Mirrors a row in `public.announcements`, merged with whether the current
/// member has read it (from `public.announcement_reads`).
class Announcement {
  final String id;
  final String? shgId;
  final String title;
  final String? body;
  final String category; // Circular | Meeting | Training | Scheme
  final DateTime createdAt;
  final bool read;

  const Announcement({
    required this.id,
    this.shgId,
    required this.title,
    this.body,
    required this.category,
    required this.createdAt,
    this.read = false,
  });

  factory Announcement.fromMap(Map<String, dynamic> map, {bool read = false}) => Announcement(
        id: map['id'] as String,
        shgId: map['shg_id'] as String?,
        title: map['title'] as String,
        body: map['body'] as String?,
        category: map['category'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
        read: read,
      );
}
