/// Mirrors a row in `public.meetings`.
class Meeting {
  final String id;
  final String shgId;
  final DateTime date;
  final String? time;
  final String? venue;
  final String? agenda;
  final String status; // upcoming | completed | cancelled

  const Meeting({
    required this.id,
    required this.shgId,
    required this.date,
    this.time,
    this.venue,
    this.agenda,
    required this.status,
  });

  factory Meeting.fromMap(Map<String, dynamic> map) => Meeting(
        id: map['id'] as String,
        shgId: map['shg_id'] as String,
        date: DateTime.parse(map['meeting_date'] as String),
        time: map['meeting_time'] as String?,
        venue: map['venue'] as String?,
        agenda: map['agenda'] as String?,
        status: map['status'] as String,
      );

  /// True once this meeting's scheduled date has passed — regardless of the
  /// stored `status`. `MeetingRepository.setStatus()` is only ever called to
  /// set `'cancelled'` (`meeting_detail_page.dart`'s "Cancel Meeting"
  /// action) — nothing in the app ever transitions a meeting to
  /// `'completed'`, so a real meeting's `status` stays `'upcoming'` forever
  /// after creation (unless explicitly cancelled), even long after its date
  /// has come and gone. Callers that need to know whether a meeting has
  /// actually happened yet (picking "the next meeting" to check into, or
  /// bucketing Upcoming vs. Past) must check this instead of trusting
  /// `status` alone.
  bool get hasPassed {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return date.isBefore(today);
  }

  /// True only on the meeting's own scheduled calendar day (day granularity,
  /// same as [hasPassed]) — used to gate the member-facing self check-in
  /// flow (`meeting_qr_page.dart`) so a member can't mark herself "present"
  /// for a meeting that is still days/weeks away. `hasPassed` alone isn't
  /// enough for that: it only excludes meetings whose date has already gone
  /// by, so a naive `!hasPassed` filter is future-inclusive and would happily
  /// resolve to an SHG's next scheduled meeting even if it's a month out,
  /// letting a member self-check-in for it (and get counted in
  /// `avg_attendance_pct`) long before it actually happens.
  bool get isScheduledToday {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  static final RegExp _time12h = RegExp(r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])$');
  static final RegExp _time24h = RegExp(r'^(\d{1,2}):(\d{2})$');

  /// Best-effort combination of [date] (day-only) with [time] into a full
  /// instant — used to compute meeting-reminder fire times
  /// (`lib/services/notification_service.dart`). `meeting_time` is stored as
  /// free-form text, not a structured time column, so the format actually
  /// seen varies with whoever produced it: `lib/data/meetings.dart`'s mock
  /// rows and `MeetingSchedulePage`'s 12-hour-locale `TimeOfDay.format()`
  /// both look like "4:00 PM", but a device with 24-hour formatting enabled
  /// produces "16:00" instead — both are handled here. Falls back to 9:00 AM
  /// on the meeting's date when [time] is null or doesn't match either
  /// shape; this only ever affects *when a reminder fires*, never the actual
  /// time shown to users elsewhere (that always renders the raw [time]
  /// string as-is).
  DateTime get scheduledAt {
    final fallback = DateTime(date.year, date.month, date.day, 9, 0);
    final t = time?.trim();
    if (t == null || t.isEmpty) return fallback;
    final m12 = _time12h.firstMatch(t);
    if (m12 != null) {
      var hour = int.parse(m12.group(1)!) % 12;
      final minute = int.parse(m12.group(2)!);
      if (m12.group(3)!.toUpperCase() == 'PM') hour += 12;
      if (minute > 59) return fallback;
      return DateTime(date.year, date.month, date.day, hour, minute);
    }
    final m24 = _time24h.firstMatch(t);
    if (m24 != null) {
      final hour = int.parse(m24.group(1)!);
      final minute = int.parse(m24.group(2)!);
      if (hour > 23 || minute > 59) return fallback;
      return DateTime(date.year, date.month, date.day, hour, minute);
    }
    return fallback;
  }
}

/// A roster member merged with their attendance for one meeting (built in
/// the repository, not a direct table mirror).
class AttendanceRow {
  final String memberId;
  final String memberName;
  final bool present;
  const AttendanceRow({required this.memberId, required this.memberName, required this.present});
}

/// One member's attendance for one completed meeting — used by the
/// Attendance Report (see `lib/pages/reports/attendance_report_page.dart`).
class MemberAttendanceRecord {
  final DateTime meetingDate;
  final String? venue;
  final bool present;
  const MemberAttendanceRecord({required this.meetingDate, this.venue, required this.present});
}

/// Mirrors a row in `public.meeting_minutes`. Each save inserts a new
/// (append-only) row — the repository reads the latest one.
class MeetingMinutes {
  final String id;
  final List<String> decisions;
  final DateTime createdAt;
  const MeetingMinutes({required this.id, required this.decisions, required this.createdAt});

  factory MeetingMinutes.fromMap(Map<String, dynamic> map) => MeetingMinutes(
        id: map['id'] as String,
        decisions: (map['decisions'] as List).map((d) => d as String).toList(),
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

/// Mirrors a row in `public.meeting_action_items`.
class MeetingActionItem {
  final String id;
  final String meetingId;
  final String task;
  final String? ownerId;
  final String? ownerName;
  final DateTime? dueDate;
  final bool done;

  const MeetingActionItem({
    required this.id,
    required this.meetingId,
    required this.task,
    this.ownerId,
    this.ownerName,
    this.dueDate,
    required this.done,
  });

  factory MeetingActionItem.fromMap(Map<String, dynamic> map) => MeetingActionItem(
        id: map['id'] as String,
        meetingId: map['meeting_id'] as String,
        task: map['task'] as String,
        ownerId: map['owner_id'] as String?,
        ownerName: (map['profiles'] as Map<String, dynamic>?)?['name'] as String?,
        dueDate: map['due_date'] != null ? DateTime.parse(map['due_date'] as String) : null,
        done: map['done'] as bool? ?? false,
      );
}
