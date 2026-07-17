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
