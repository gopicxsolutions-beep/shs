import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/repositories/admin_repository.dart';
import 'package:shg_saathi/repositories/scheme_repository.dart';
import 'package:shg_saathi/repositories/training_repository.dart';
import 'package:shg_saathi/services/supabase_service.dart';

/// Regression coverage for two HIGH-severity staleness bugs an adversarial
/// review found in `AdminRepository.fetchDashboardStats()`'s demo-mode
/// branch: `trainingCompletionPct` and `pendingReviewCount` used to be
/// computed straight off the immutable const mock catalogs
/// (`lib/data/training.dart`, `lib/data/schemes.dart`) and never consulted
/// the *other* repositories' actual mutable demo-mode state — so deciding a
/// scheme application via `SchemeApplicationsReviewPage`
/// (`SchemeRepository.decideApplication`), or passing a course's quiz via
/// `CourseQuizPage` (`TrainingRepository.markCertified`), never moved this
/// dashboard's numbers at all, even though the real pages those actions live
/// on (`fetchPendingApplications()`, `fetchMyProgress()`) correctly
/// reflected the change immediately.
///
/// Kept in its own file, separate from
/// admin_dashboard_stats_repository_test.dart: `SchemeRepository`/
/// `TrainingRepository` track demo-mode local state in static fields with no
/// reset hook, so mutating it here must not leak into that file's own
/// fixed-baseline assertions (48%, pending count 2). `flutter test`/
/// `dart test` run each test file in its own isolate, so this file's
/// mutations are invisible to every other test file.
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  test('pendingReviewCount reflects SchemeRepository.decideApplication(), not the frozen mock catalog', () async {
    // Starting point: lib/data/schemes.dart's sc2 (under_review) and sc3
    // (applied) are the only two schemes still awaiting a decision.
    final before = await AdminRepository().fetchDashboardStats();
    expect(before.pendingReviewCount, 2);

    final schemeRepo = SchemeRepository();
    final pendingBefore = await schemeRepo.fetchPendingApplications();
    expect(pendingBefore.map((a) => a.applicationId).toSet(), {'sc2', 'sc3'});

    // A staff account decides both remaining applications...
    await schemeRepo.decideApplication('sc2', approve: true);
    await schemeRepo.decideApplication('sc3', approve: false);

    // ...which correctly empties the real review queue used by
    // SchemeApplicationsReviewPage itself...
    final pendingAfter = await schemeRepo.fetchPendingApplications();
    expect(pendingAfter, isEmpty);

    // ...and the dashboard stat must agree, not keep reporting the stale
    // starting count of 2 (the exact bug: it used to).
    final after = await AdminRepository().fetchDashboardStats();
    expect(after.pendingReviewCount, 0);
  });

  test('trainingCompletionPct reflects TrainingRepository.markCertified(), not the frozen mock catalog', () async {
    // Starting point: lib/data/training.dart's progress values [100, 60, 30,
    // 0, 0, 100] average 48.33 -> rounds to 48.
    final before = await AdminRepository().fetchDashboardStats();
    expect(before.trainingCompletionPct, 48);

    final trainingRepo = TrainingRepository();
    const courseIds = ['co1', 'co2', 'co3', 'co4', 'co5', 'co6'];
    for (final id in courseIds) {
      await trainingRepo.markCertified(id, null);
    }

    // Every course now genuinely reports 100% progress, per
    // TrainingRepository.fetchMyProgress() itself...
    final progressAfter = await trainingRepo.fetchMyProgress(null);
    expect(progressAfter.values.every((p) => p.progress == 100), isTrue);

    // ...and the dashboard stat must agree, not keep reporting the stale
    // starting 48% (the exact bug: it used to).
    final after = await AdminRepository().fetchDashboardStats();
    expect(after.trainingCompletionPct, 100);
  });
}
