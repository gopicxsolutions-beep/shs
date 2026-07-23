import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/data/members.dart';
import 'package:shg_saathi/models/admin.dart';
import 'package:shg_saathi/repositories/admin_repository.dart';
import 'package:shg_saathi/services/supabase_service.dart';

/// Direct coverage of `AdminRepository.fetchDashboardStats()`'s demo-mode
/// computation — the numbers that used to be static constants in
/// `admin_dashboard.dart` (`_trainingCompletion = 87`,
/// `_pendingVerificationCount = 3`, a fixed 3-row `_recentActivity`) with no
/// backing data, never changing regardless of what the mock data actually
/// said. See test/pages/admin_dashboard_stats_test.dart for the same
/// numbers checked at the rendered-widget level.
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
    AdminRepository.debugMembersOverride = null;
  });

  test('trainingCompletionPct is the real average of mock course progress (48%), not a fixed number', () async {
    final stats = await AdminRepository().fetchDashboardStats();
    // lib/data/training.dart: progress values 100, 60, 30, 0, 0, 100 ->
    // average 48.33 -> rounds to 48.
    expect(stats.trainingCompletionPct, 48);
  });

  test('pendingReviewCount is the real count of applied/under_review mock schemes (2), not a fixed number', () async {
    final stats = await AdminRepository().fetchDashboardStats();
    // lib/data/schemes.dart: sc2 (under_review) and sc3 (applied) are the
    // only two still awaiting a staff decision.
    expect(stats.pendingReviewCount, 2);
  });

  test('recentActivity is derived from real mock records, ordered newest-first, capped at 5', () async {
    final stats = await AdminRepository().fetchDashboardStats();
    expect(stats.recentActivity, isNotEmpty);
    expect(stats.recentActivity.length, lessThanOrEqualTo(5));
    for (var i = 0; i < stats.recentActivity.length - 1; i++) {
      final a = stats.recentActivity[i].occurredAt;
      final b = stats.recentActivity[i + 1].occurredAt;
      expect(a.isAfter(b) || a.isAtSameMomentAs(b), isTrue, reason: 'recentActivity must be newest-first');
    }
    // Every entry must be a real derived record (document or new-user kind
    // with a real subject name), not a disconnected fabricated string like
    // the old "Scheduled backup completed".
    for (final item in stats.recentActivity) {
      expect(item.kind == AdminActivityKind.document || item.kind == AdminActivityKind.newUser, isTrue, reason: 'unexpected activity kind: ${item.kind}');
      expect(item.subjectName, isNotEmpty);
    }
  });

  test('recentActivity reflects a debugMembersOverride change (proves it is derived, not fixed)', () async {
    AdminRepository.debugMembersOverride = const [
      // A joining date far in the future guarantees this member sorts
      // first among the merged document/member activity feed.
      Member(id: 'zz1', name: '__TEST__ Newest Member', mobile: '000', aadhaar: 'XXXX', role: 'Member', joiningDate: '01 Jan 2027', savings: 0, loanOutstanding: 0, attendance: 0, status: 'active'),
    ];
    addTearDown(() => AdminRepository.debugMembersOverride = null);

    final stats = await AdminRepository().fetchDashboardStats();
    expect(stats.recentActivity.first.kind, AdminActivityKind.newUser);
    expect(stats.recentActivity.first.subjectName, '__TEST__ Newest Member');
  });

  group('trainingCompletionPctFrom — live-mode denominator (regression: platform-wide adoption bias)', () {
    // AdminRepository.fetchDashboardStats()'s live-mode branch used to
    // average `course_progress.progress` only over the rows that already
    // exist — i.e. only member/course pairs a member had actually opened —
    // silently excluding every member who'd never opened any course from
    // both sides of the average, instead of counting them as 0%. This pure
    // arithmetic is factored out of the live branch specifically so it can
    // be exercised here without a live Supabase project (none is reachable
    // from this dev environment).
    test('a handful of early adopters out of a much larger, mostly-untouched platform reads as near-zero adoption, not near-100%', () {
      // 500 platform members, 6 courses in the catalog (mirrors this app's
      // own demo course count) — only 3 members have ever opened any
      // course, each finishing exactly one to 100%. Sum of the *existing*
      // course_progress rows is 300.
      const progressSum = 300;
      const totalMembers = 500;
      const totalCourses = 6;

      // The bug: averaging only over the 3 existing rows (the pre-fix
      // computation) reads as ~100% adoption.
      const oldBrokenPct = progressSum / 3;
      expect(oldBrokenPct, 100);

      final fixedPct = AdminRepository.trainingCompletionPctFrom(progressSum: progressSum, totalMembers: totalMembers, totalCourses: totalCourses);
      // True platform-wide adoption: 300 / (500*6) = 0.1% -> rounds to 0,
      // nowhere near the old formula's 100%.
      expect(fixedPct, 0);
    });

    test('every member having completed every course correctly reads as a genuine 100%', () {
      final pct = AdminRepository.trainingCompletionPctFrom(progressSum: 500 * 6 * 100, totalMembers: 500, totalCourses: 6);
      expect(pct, 100);
    });

    test('zero members or zero courses yields 0%, not a divide-by-zero crash', () {
      expect(AdminRepository.trainingCompletionPctFrom(progressSum: 0, totalMembers: 0, totalCourses: 6), 0);
      expect(AdminRepository.trainingCompletionPctFrom(progressSum: 0, totalMembers: 500, totalCourses: 0), 0);
    });
  });
}
