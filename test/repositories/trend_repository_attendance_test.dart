import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/repositories/meeting_repository.dart';
import 'package:shg_saathi/repositories/trend_repository.dart';
import 'package:shg_saathi/services/supabase_service.dart';

/// Direct coverage of `TrendRepository.attendanceTrend`'s demo-mode branch,
/// which used to unconditionally return a fixed illustrative array
/// (`_mockTrend(const [78, 82, 75, 88, 91, 85])`) regardless of `shgId` and
/// without ever consulting `MeetingRepository`'s cancellation/attendance
/// state — see `test/repositories/meeting_report_consistency_test.dart` for
/// the end-to-end Member Report vs. SHG Report symptom this caused. Kept in
/// its own file/isolate so the exact expected percentages below don't have
/// to account for any other test's mutations to the shared session-local
/// mock meeting state.
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  test('demo-mode attendanceTrend reflects MeetingRepository state instead of a fixed array: a manual mark and then a cancellation both move the same month\'s percentage', () async {
    final repo = MeetingRepository();
    final trendRepo = TrendRepository();

    final before = await trendRepo.attendanceTrend(shgId: 'demo-shg');
    final beforeJune = before.firstWhere((p) => p.month == 'Jun');
    // Baseline: mt2/mt3/mt4/mt5 (the mock's only 'completed' meetings, all
    // dated in June 2026) are each present-by-default (12/12), so June
    // reads 100% before any manual mark or cancellation this run.
    expect(beforeJune.value, closeTo(100, 0.01));

    await repo.markAttendance('mt3', 'm1', false);
    final afterMark = await trendRepo.attendanceTrend(shgId: 'demo-shg');
    final afterMarkJune = afterMark.firstWhere((p) => p.month == 'Jun');
    // A manual attendance edit on a completed meeting is reflected too, not
    // just a cancellation — one of 48 (12 members * 4 meetings) now absent.
    expect(afterMarkJune.value, closeTo(47 / 48 * 100, 0.01));

    await repo.setStatus('mt3', 'cancelled');
    final afterCancel = await trendRepo.attendanceTrend(shgId: 'demo-shg');
    final afterCancelJune = afterCancel.firstWhere((p) => p.month == 'Jun');
    // Cancelling the meeting that was just marked down removes its 11/12
    // from the June bucket entirely, leaving the 3 remaining fully-present
    // meetings at 100% — a real, visible change driven by MeetingRepository
    // state, not a static illustrative constant that would have stayed at
    // its fixed value through both of these mutations.
    expect(afterCancelJune.value, closeTo(100, 0.01));
  });
}
