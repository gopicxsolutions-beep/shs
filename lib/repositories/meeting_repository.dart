import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/members.dart' as mock_members;
import '../data/meetings.dart' as mock;
import '../models/meeting.dart';
import '../services/supabase_service.dart';

/// Backed by `public.meetings` + related tables when Supabase is configured;
/// falls back to `lib/data/meetings.dart` / `lib/data/members.dart` otherwise
/// (same dual-mode pattern as [SavingsRepository]).
class MeetingRepository {
  SupabaseClient get _client => SupabaseService.instance.client;
  bool get _live => SupabaseService.isConfigured;

  // Keyed by "$meetingId:$memberId" — see fetchAttendance/markAttendance.
  static final Map<String, bool> _locallyMarked = {};

  // Demo mode has no backing table, so a scheduled meeting would otherwise
  // vanish the instant the list reloads — track it here so it survives for
  // the rest of the session, mirroring AnnouncementRepository._locallyRead.
  static final List<Meeting> _locallyScheduled = [];

  // Demo mode has no backing table for a status transition either — without
  // this, tapping "Cancel Meeting" (meeting_detail_page.dart) would silently
  // no-op in demo mode (setStatus() below returns immediately when !_live)
  // and the meeting would keep showing as upcoming for the rest of the
  // session, the exact "not still show as upcoming" regression this exists
  // to prevent. Applied as a status override at read time (fetchForShg/
  // fetchById/_mockMeetings/fetchAttendanceHistory) rather than mutating the
  // underlying `Meeting`/mock records in place, mirroring `_locallyMarked`.
  static final Set<String> _locallyCancelled = {};

  // Test-only seam (null by default, so every existing test keeps seeing
  // the exact short mock_members.members it always has).
  // test/routes/long_content_stress_test.dart sets this (mirroring
  // ShgRepository.debugMembersOverride/AdminRepository.debugMembersOverride
  // — kept as a separate field rather than a shared import to avoid a new
  // cross-repository dependency existing only for this test seam) to
  // exercise a realistic long member name on the attendance roster at a
  // normal viewport, then resets it — no change to lib/data/members.dart's
  // shared mock records themselves.
  static List<mock_members.Member>? debugMembersOverride;

  Future<List<Meeting>> fetchForShg(String? shgId) async {
    if (!_live) return [..._locallyScheduled.reversed.map(_withLocalCancelOverlay), ..._mockMeetings()];
    if (shgId == null) return [];
    final rows = await _client.from('meetings').select().eq('shg_id', shgId).order('meeting_date', ascending: false);
    return (rows as List).map((r) => Meeting.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<Meeting?> fetchById(String id) async {
    if (!_live) {
      final matches = [..._locallyScheduled.map(_withLocalCancelOverlay), ..._mockMeetings()].where((m) => m.id == id);
      return matches.isEmpty ? null : matches.first;
    }
    final row = await _client.from('meetings').select().eq('id', id).maybeSingle();
    return row == null ? null : Meeting.fromMap(row);
  }

  /// Overlays a locally-recorded cancellation (see `_locallyCancelled`) onto
  /// a demo-mode meeting at read time, without mutating the original
  /// (immutable) `Meeting`.
  Meeting _withLocalCancelOverlay(Meeting m) {
    if (m.status == 'cancelled' || !_locallyCancelled.contains(m.id)) return m;
    return Meeting(id: m.id, shgId: m.shgId, date: m.date, time: m.time, venue: m.venue, agenda: m.agenda, status: 'cancelled');
  }

  /// Returns whether the meeting was actually saved — `false` (not an
  /// exception) when a live staff account has no SHG to schedule for, so
  /// the caller can tell that apart from a genuine success instead of
  /// showing "Meeting scheduled" for a write that never happened.
  Future<bool> schedule({
    required String? shgId,
    required DateTime date,
    required String time,
    required String venue,
    required String agenda,
  }) async {
    if (!_live) {
      _locallyScheduled.add(Meeting(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        shgId: shgId ?? 'demo-shg',
        date: date,
        time: time,
        venue: venue,
        agenda: agenda,
        status: 'upcoming',
      ));
      return true;
    }
    if (shgId == null) return false;
    await _client.from('meetings').insert({
      'shg_id': shgId,
      'meeting_date': date.toIso8601String().split('T').first,
      'meeting_time': time,
      'venue': venue,
      'agenda': agenda,
      'status': 'upcoming',
    });
    return true;
  }

  /// Called by `meeting_detail_page.dart`'s "Cancel Meeting" action (the
  /// only in-app call site — no code path ever transitions a meeting to
  /// `'completed'`; that stays inferred from `Meeting.hasPassed`/the
  /// `meeting_date < today` queries below, never written to the column).
  Future<void> setStatus(String id, String status) async {
    if (!_live) {
      if (status == 'cancelled') _locallyCancelled.add(id);
      return;
    }
    await _client.from('meetings').update({'status': status}).eq('id', id);
  }

  /// The SHG's member roster (id + name) — used to build attendance sheets.
  Future<List<(String id, String name)>> fetchRoster(String? shgId) async {
    if (!_live) {
      return (debugMembersOverride ?? mock_members.members).map((m) => (m.id, m.name)).toList();
    }
    if (shgId == null) return [];
    final rows = await _client.from('profiles').select('id, name').eq('shg_id', shgId).order('name');
    return (rows as List).map((r) => (r['id'] as String, r['name'] as String)).toList();
  }

  /// Full roster merged with this meeting's attendance rows (absent by
  /// default for anyone not yet marked).
  Future<List<AttendanceRow>> fetchAttendance(String meetingId, String? shgId) async {
    final roster = await fetchRoster(shgId);
    if (!_live) {
      // Demo mode has no backing table, so a mark would otherwise revert to
      // "everyone present" the instant this page reloads — track it here so
      // it survives for the rest of the session, mirroring
      // AnnouncementRepository._locallyRead.
      return roster.map((m) => AttendanceRow(memberId: m.$1, memberName: m.$2, present: _locallyMarked['$meetingId:${m.$1}'] ?? true)).toList();
    }
    final rows = await _client.from('meeting_attendance').select('member_id, present').eq('meeting_id', meetingId);
    final presentById = <String, bool>{for (final r in rows as List) r['member_id'] as String: r['present'] as bool? ?? false};
    return roster.map((m) => AttendanceRow(memberId: m.$1, memberName: m.$2, present: presentById[m.$1] ?? false)).toList();
  }

  /// This member's attendance across every completed meeting for their
  /// SHG, newest first — backs the Attendance Report (see
  /// `lib/pages/reports/attendance_report_page.dart`).
  Future<List<MemberAttendanceRecord>> fetchAttendanceHistory(String? memberId, String? shgId) async {
    if (!_live) {
      // Only completed meetings — an upcoming one hasn't happened yet, so
      // there's nothing to have attended. Consults the same `_locallyMarked`
      // map fetchAttendance() reads, so a leader's mark on a completed
      // meeting is reflected here too, instead of this report silently
      // disagreeing with what the leader just set. `_mockMeetings()`
      // itself already overlays a local cancellation onto `status` (see
      // `_locallyCancelled`), so a meeting cancelled after the fact drops
      // out of this history instead of still counting as attended/completed.
      return _mockMeetings()
          .where((m) => m.status == 'completed')
          .map((m) => MemberAttendanceRecord(meetingDate: m.date, venue: m.venue, present: _locallyMarked['${m.id}:$memberId'] ?? true))
          .toList();
    }
    if (memberId == null || shgId == null) return const [];
    // Filtering on `status = 'completed'` here would always return zero
    // rows in live mode: the only status transition ever written is to
    // 'cancelled' (see `setStatus`'s doc comment) — a meeting's status
    // never advances to 'completed' no matter how long ago it happened.
    // Use the meeting's own date instead — a meeting is "done" once its
    // date has passed, which is the ground truth this report actually
    // needs (and matches the demo-mode branch's `status == 'completed'`
    // mock data, which was authored assuming this transition would work).
    // `.neq('status', 'cancelled')` still applies on top of the date
    // filter, so a meeting explicitly cancelled after its date passed is
    // correctly excluded here instead of counting as a completed meeting
    // with 0% attendance.
    final todayStr = DateTime.now().toIso8601String().split('T').first;
    final meetings = await _client
        .from('meetings')
        .select('id, meeting_date, venue')
        .eq('shg_id', shgId)
        .neq('status', 'cancelled')
        .lt('meeting_date', todayStr)
        .order('meeting_date', ascending: false);
    final meetingList = meetings as List;
    if (meetingList.isEmpty) return const [];
    final meetingIds = meetingList.map((m) => (m as Map<String, dynamic>)['id'] as String).toList();
    final attendance = await _client.from('meeting_attendance').select('meeting_id, present').eq('member_id', memberId).inFilter('meeting_id', meetingIds);
    final presentByMeeting = <String, bool>{for (final r in attendance as List) (r as Map<String, dynamic>)['meeting_id'] as String: r['present'] as bool? ?? false};
    return meetingList.map((m) {
      final map = m as Map<String, dynamic>;
      final id = map['id'] as String;
      return MemberAttendanceRecord(meetingDate: DateTime.parse(map['meeting_date'] as String), venue: map['venue'] as String?, present: presentByMeeting[id] ?? false);
    }).toList();
  }

  /// A cancelled meeting is never attendance-editable — `meeting_attendance_
  /// page.dart`'s picker already excludes cancelled meetings from what a
  /// leader can even select, but this repository method is the single
  /// choke point every caller (that picker, plus `meeting_qr_page.dart`'s
  /// member self-check-in) actually writes through, so the real guard
  /// belongs here rather than relying solely on each UI caller re-deriving
  /// the same exclusion correctly. Without this, a leader could still pick
  /// an already-cancelled meeting from the dropdown (which only used the
  /// upcoming-and-not-passed check to choose its *default* selection, never
  /// to restrict which meetings were selectable) and flip attendance
  /// switches for it after cancellation — writing fresh attendance rows
  /// tied to a cancelled meeting, visibly inconsistent with that meeting's
  /// own detail page (a red "cancelled" badge sitting directly above a
  /// live, freshly-editable roster). Re-derives the meeting's status via
  /// `fetchById` (not a raw status flag passed in) so this stays correct
  /// under demo mode's session-local `_locallyCancelled` overlay too, not
  /// just a live 'status' column value. In live mode the real boundary is
  /// still the `meeting_attendance` INSERT/UPDATE RLS policies (this check
  /// is UX/defense-in-depth, not the authorization boundary — see
  /// `0042_meeting_cancel_and_attendance_lifecycle_guards.sql`).
  Future<void> markAttendance(String meetingId, String memberId, bool present) async {
    final meeting = await fetchById(meetingId);
    if (meeting?.status == 'cancelled') {
      throw StateError('Cannot mark attendance for a cancelled meeting.');
    }
    if (!_live) {
      _locallyMarked['$meetingId:$memberId'] = present;
      return;
    }
    await _client.from('meeting_attendance').upsert({
      'meeting_id': meetingId,
      'member_id': memberId,
      'present': present,
      'marked_at': DateTime.now().toIso8601String(),
    }, onConflict: 'meeting_id,member_id');
  }

  Future<MeetingMinutes?> fetchLatestMinutes(String meetingId) async {
    if (!_live) return null;
    final rows = await _client.from('meeting_minutes').select().eq('meeting_id', meetingId).order('created_at', ascending: false).limit(1);
    final list = rows as List;
    return list.isEmpty ? null : MeetingMinutes.fromMap(list.first as Map<String, dynamic>);
  }

  Future<void> saveMinutes(String meetingId, List<String> decisions) async {
    if (!_live) return;
    await _client.from('meeting_minutes').insert({'meeting_id': meetingId, 'decisions': decisions});
  }

  Future<List<MeetingActionItem>> fetchActionItems(String meetingId) async {
    if (!_live) return const [];
    final rows = await _client.from('meeting_action_items').select('*, profiles(name)').eq('meeting_id', meetingId).order('due_date');
    return (rows as List).map((r) => MeetingActionItem.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> addActionItem(String meetingId, String task, {String? ownerId, DateTime? dueDate}) async {
    if (!_live) return;
    await _client.from('meeting_action_items').insert({
      'meeting_id': meetingId,
      'task': task,
      'owner_id': ?ownerId,
      if (dueDate != null) 'due_date': dueDate.toIso8601String().split('T').first,
    });
  }

  Future<void> toggleActionItem(String id, bool done) async {
    if (!_live) return;
    await _client.from('meeting_action_items').update({'done': done}).eq('id', id);
  }

  List<Meeting> _mockMeetings() => mock.meetings
      .map((m) => Meeting(
            id: m.id,
            shgId: 'demo-shg',
            date: _parseMockDate(m.date),
            time: m.time,
            venue: m.venue,
            agenda: m.agenda,
            // `_locallyCancelled` overrides the static mock's own status —
            // see its doc comment — so cancelling one of these illustrative
            // meetings actually sticks for the rest of the session instead
            // of the underlying `lib/data/meetings.dart` record (which is
            // never mutated) winning back on the very next read.
            status: _locallyCancelled.contains(m.id) ? 'cancelled' : m.status,
          ))
      .toList();

  DateTime _parseMockDate(String s) {
    try {
      return DateFormat('dd MMM yyyy').parse(s);
    } catch (_) {
      return DateTime.now();
    }
  }
}
