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
    // `.limit(300)` — this was a fully unbounded query (every SHG-scoped
    // announcement plus every platform-wide one ever posted, fetched on
    // every page load), the same anti-pattern already found and fixed
    // repeatedly elsewhere (shg_documents, financial ledger, audit log,
    // CRP/CLF SHG list, admin users/SHGs) but missed here.
    final rows = shgId == null
        ? await _client.from('announcements').select().filter('shg_id', 'is', null).order('created_at', ascending: false).limit(300)
        : await _client.from('announcements').select().or('shg_id.eq.$shgId,shg_id.is.null').order('created_at', ascending: false).limit(300);
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

  /// Returns whether the announcement was actually posted — `false` (not
  /// an exception) when a live leader account somehow has no SHG to post it
  /// to (defensive; shouldn't happen in practice — leader status implies an
  /// approved SHG), so the caller can tell that apart from a genuine success
  /// instead of silently clearing the compose form for a write that never
  /// happened.
  ///
  /// [platformWide] is the staff path (`shg_id: null`) — RLS's `is_staff()`
  /// bypass already permits this (see `announcements_insert_leader_or_staff`),
  /// but until this parameter existed no caller ever passed `shgId: null`, so
  /// staff could never actually reach it through the app despite it being
  /// the one posting capability the SRS specifically promises them. When
  /// `true`, [shgId] is ignored entirely — a staff account's own `shgId` (if
  /// it even has one) is irrelevant to a platform-wide post.
  Future<bool> post({required String? shgId, required String? createdBy, required String title, required String body, required String category, bool platformWide = false}) async {
    if (!_live) return false;
    if (shgId == null && !platformWide) return false;
    await _client.from('announcements').insert({
      'shg_id': platformWide ? null : shgId,
      'created_by': createdBy,
      'title': title,
      'body': body,
      'category': category,
    });
    return true;
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
