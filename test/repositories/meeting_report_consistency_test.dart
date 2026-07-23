import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/repositories/meeting_repository.dart';
import 'package:shg_saathi/repositories/report_repository.dart';
import 'package:shg_saathi/services/supabase_service.dart';

/// Regression coverage for a demo-mode inconsistency an adversarial review
/// flagged: `ReportRepository.fetchMemberReport`'s demo branch correctly
/// reads through `MeetingRepository` (so a same-session cancellation is
/// reflected in `meetingsTotal`), but `ReportRepository.fetchShgReport`'s
/// demo-mode `avgAttendancePct` derives from `TrendRepository.
/// attendanceTrend`, and THAT method's demo branch used to unconditionally
/// return a hardcoded illustrative array — ignoring `shgId` and never
/// consulting `MeetingRepository`'s cancellation state at all. A leader
/// cancelling a meeting in demo mode would see the Member Report's
/// `meetingsTotal` correctly drop by one while the SHG Performance Report /
/// CRP SHG Health screens (both backed by `fetchShgReport`) kept showing
/// the exact same `avgAttendancePct` as before — disagreeing with each
/// other in the same session.
///
/// See also `test/repositories/trend_repository_attendance_test.dart` for
/// direct coverage of `TrendRepository.attendanceTrend` itself (kept in its
/// own file/isolate so its byte-for-byte expected percentages don't have to
/// account for this file's own mutations to the shared mock meetings).
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  test('cancelling a meeting with real recorded attendance changes the SHG-level avgAttendancePct, consistent with the member-level meetingsTotal drop in the same run', () async {
    final repo = MeetingRepository();
    final reportRepo = ReportRepository();

    // `mt2` (28 Jun 2026) is one of the fixed mock 'completed' meetings
    // (lib/data/meetings.dart) and shares its month (June 2026) with every
    // other completed mock meeting (mt3/mt4/mt5) — mark one member absent
    // so mt2's own attendance ratio actually differs from its month-mates
    // (which all default to 100% present via `_locallyMarked[...] ?? true`
    // until explicitly marked otherwise). Without this, removing a meeting
    // whose ratio is identical to every other meeting sharing its month
    // wouldn't move that month's percentage at all, and this test wouldn't
    // actually distinguish "fixed" from "still broken".
    await repo.markAttendance('mt2', 'm12', false);

    final beforeShg = await reportRepo.fetchShgReport('demo-shg');
    final beforeMember = await reportRepo.fetchMemberReport(memberId: 'demo-member', shgId: 'demo-shg');
    expect(beforeMember.meetingsTotal, greaterThan(0));

    await repo.setStatus('mt2', 'cancelled');

    final afterShg = await reportRepo.fetchShgReport('demo-shg');
    final afterMember = await reportRepo.fetchMemberReport(memberId: 'demo-member', shgId: 'demo-shg');

    // The member-level report already correctly dropped this by one before
    // this fix — kept here as the "sibling" half of the consistency check
    // the bug report describes.
    expect(afterMember.meetingsTotal, beforeMember.meetingsTotal - 1);

    // The actual bug: this used to be IDENTICAL before and after, because
    // `TrendRepository.attendanceTrend`'s demo branch never consulted
    // `MeetingRepository` (or `shgId`) at all.
    expect(afterShg.avgAttendancePct, isNot(closeTo(beforeShg.avgAttendancePct, 0.0001)));

    // Exact expected shift, derived by hand: mt2/mt3/mt4/mt5 are the only
    // 'completed' meetings in the mock set, all dated in June 2026, so they
    // all bucket into the same monthly point (`TrendRepository` aggregates
    // present/total across every attendance row in the month, not an
    // average of each meeting's own percentage), and the other 5 of the 6
    // plotted months are always 0 (no completed-meeting data at all).
    final beforeJuneAggregatePct = (11 + 12 + 12 + 12) / (12 * 4) * 100; // mt2 (11/12) + mt3/mt4/mt5 (12/12 each)
    final afterJuneAggregatePct = (12 + 12 + 12) / (12 * 3) * 100; // mt2 excluded (cancelled); mt3/mt4/mt5 only
    expect(beforeShg.avgAttendancePct, closeTo(beforeJuneAggregatePct / 6, 0.01));
    expect(afterShg.avgAttendancePct, closeTo(afterJuneAggregatePct / 6, 0.01));
  });
}
