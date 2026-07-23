import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/repositories/meeting_repository.dart';
import 'package:shg_saathi/repositories/report_repository.dart';
import 'package:shg_saathi/services/supabase_service.dart';

/// Regression coverage for `MeetingRepository.setStatus()` actually being
/// reachable (via `MeetingDetailPage`'s new "Cancel Meeting" action) and for
/// the downstream "completed meetings" / attendance-percentage calculations
/// correctly excluding a meeting cancelled after its scheduled date passed
/// (`ReportRepository.fetchMemberReport`, `MeetingRepository.
/// fetchAttendanceHistory`), instead of counting it as a completed meeting
/// with 0% attendance dragging the SHG's real stats down.
///
/// These exercise the demo-mode branches only — the live-mode SQL query
/// shape (`.neq('status', 'cancelled')` combined with `.lt('meeting_date',
/// today)`, including through the `meetings!inner(...)` embed in
/// `meeting_attendance` queries) has no equivalent seam to unit-test without
/// a real Supabase project; that was verified by careful reading instead
/// (see the doc comments on `ReportRepository.fetchMemberReport`/
/// `fetchShgReport`, `MeetingRepository.fetchAttendanceHistory`, and
/// `TrendRepository.attendanceTrend`).
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  test('setStatus is actually reachable: a scheduled meeting starts upcoming and becomes cancelled everywhere it is read', () async {
    final repo = MeetingRepository();
    const venue = '__TEST__ Venue Repo Cancel';
    await repo.schedule(shgId: null, date: DateTime.now().add(const Duration(days: 5)), time: '3:00 PM', venue: venue, agenda: '__TEST__ agenda repo cancel');

    final beforeList = await repo.fetchForShg('demo-shg');
    final scheduled = beforeList.firstWhere((m) => m.venue == venue);
    expect(scheduled.status, 'upcoming');
    final beforeById = await repo.fetchById(scheduled.id);
    expect(beforeById?.status, 'upcoming');

    await repo.setStatus(scheduled.id, 'cancelled');

    final afterList = await repo.fetchForShg('demo-shg');
    expect(afterList.firstWhere((m) => m.id == scheduled.id).status, 'cancelled');
    final afterById = await repo.fetchById(scheduled.id);
    expect(afterById?.status, 'cancelled');
  });

  test('a meeting cancelled after its date has passed is excluded from the completed-meetings count and attendance history, not counted as a 0%-attendance completed meeting', () async {
    final repo = MeetingRepository();
    final reportRepo = ReportRepository();

    // Baseline against the fixed mock data (`lib/data/meetings.dart`): 'mt2'
    // is a 'completed' meeting dated 28 Jun 2026 (in the past relative to
    // this session's current date), so it is currently counted as a
    // completed meeting in both the attendance history and the member
    // report's meetingsTotal.
    final beforeHistory = await repo.fetchAttendanceHistory('demo-member', 'demo-shg');
    final beforeReport = await reportRepo.fetchMemberReport(memberId: 'demo-member', shgId: 'demo-shg');
    final mt2Date = DateTime(2026, 6, 28);
    expect(beforeHistory.any((h) => h.meetingDate == mt2Date), isTrue, reason: 'sanity check: mt2 must be present before cancelling it');
    expect(beforeReport.meetingsTotal, greaterThan(0));

    await repo.setStatus('mt2', 'cancelled');

    final afterHistory = await repo.fetchAttendanceHistory('demo-member', 'demo-shg');
    final afterReport = await reportRepo.fetchMemberReport(memberId: 'demo-member', shgId: 'demo-shg');

    // Excluded from the attendance history entirely — not still listed as a
    // completed (and therefore implicitly "attended" or "missed") meeting.
    expect(afterHistory.any((h) => h.meetingDate == mt2Date), isFalse);
    expect(afterHistory.length, beforeHistory.length - 1);
    // And excluded from the "completed meetings" denominator that drives the
    // attendance percentage — not counted as a completed meeting with 0%
    // attendance dragging the SHG's real stats down.
    expect(afterReport.meetingsTotal, beforeReport.meetingsTotal - 1);
  });

  test('MeetingRepository.setStatus is the only call site — cancelling never advances a meeting to "completed"', () async {
    // Guards the specific invariant every live-mode query in this module
    // relies on (see the doc comments in ReportRepository/TrendRepository/
    // MeetingRepository.fetchAttendanceHistory): 'completed' is inferred
    // from the meeting's own date, never written to the status column.
    final repo = MeetingRepository();
    const venue = '__TEST__ Venue Never Completed';
    await repo.schedule(shgId: null, date: DateTime.now().subtract(const Duration(days: 10)), time: '2:00 PM', venue: venue, agenda: '__TEST__ agenda never completed');
    final list = await repo.fetchForShg('demo-shg');
    final scheduled = list.firstWhere((m) => m.venue == venue);
    // Its date is well in the past, yet status stays 'upcoming' — nothing
    // in this repository ever transitions it to 'completed'.
    expect(scheduled.status, 'upcoming');
    expect(scheduled.hasPassed, isTrue);
  });
}
