import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/announcements.dart' as mock;
import '../models/announcement.dart';
import '../services/supabase_service.dart';

/// Backed by `public.announcements` / `public.announcement_reads` when
/// Supabase is configured; falls back to `lib/data/announcements.dart`
/// otherwise.
class AnnouncementRepository {
  SupabaseClient get _client => SupabaseService.instance.client;
  bool get _live => SupabaseService.isConfigured;

  // Demo mode has no backing table to persist read receipts to, so opening
  // an announcement would otherwise never clear its "Unread" badge for the
  // rest of the session. Static so it survives this repository being
  // re-instantiated per page while the app is running.
  static final Set<String> _locallyRead = {};

  Future<List<Announcement>> fetchForShg(String? shgId, String? memberId) async {
    if (!_live) {
      return mock.announcements
          .map((a) => Announcement(id: a.id, title: a.title, body: a.body, category: a.category, createdAt: _parseMockDate(a.date), read: a.read || _locallyRead.contains(a.id)))
          .toList();
    }
    // A live staff account without an SHG still has none of its own to
    // scope to, but should still see federation-wide announcements
    // (shg_id is null) rather than falling back to demo content.
    final rows = shgId == null
        ? await _client.from('announcements').select().filter('shg_id', 'is', null).order('created_at', ascending: false)
        : await _client.from('announcements').select().or('shg_id.eq.$shgId,shg_id.is.null').order('created_at', ascending: false);
    final readRows = memberId == null ? [] : await _client.from('announcement_reads').select('announcement_id').eq('member_id', memberId);
    final readIds = {for (final r in readRows) (r as Map<String, dynamic>)['announcement_id'] as String};
    return (rows as List).map((r) {
      final map = r as Map<String, dynamic>;
      return Announcement.fromMap(map, read: readIds.contains(map['id']));
    }).toList();
  }

  Future<Announcement?> fetchById(String id, String? memberId) async {
    if (!_live) {
      final matches = mock.announcements.where((a) => a.id == id);
      if (matches.isEmpty) return null;
      final a = matches.first;
      return Announcement(id: a.id, title: a.title, body: a.body, category: a.category, createdAt: _parseMockDate(a.date), read: a.read || _locallyRead.contains(a.id));
    }
    final row = await _client.from('announcements').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    final isRead = memberId == null ? false : await _client.from('announcement_reads').select('member_id').eq('announcement_id', id).eq('member_id', memberId).maybeSingle() != null;
    return Announcement.fromMap(row, read: isRead);
  }

  Future<void> markRead(String announcementId, String? memberId) async {
    if (!_live || memberId == null) {
      _locallyRead.add(announcementId);
      return;
    }
    await _client.from('announcement_reads').upsert({
      'announcement_id': announcementId,
      'member_id': memberId,
    }, onConflict: 'announcement_id,member_id');
  }

  Future<void> post({required String? shgId, required String? createdBy, required String title, required String body, required String category}) async {
    if (!_live || shgId == null) return;
    await _client.from('announcements').insert({
      'shg_id': shgId,
      'created_by': createdBy,
      'title': title,
      'body': body,
      'category': category,
    });
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
