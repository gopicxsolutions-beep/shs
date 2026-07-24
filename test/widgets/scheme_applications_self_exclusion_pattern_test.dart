import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/models/scheme.dart';

/// Regression coverage for `SchemeApplicationsReviewPage`'s self-exclusion
/// filter (`allApps.where((a) => a.memberId != myId)`) — the round-97 fix
/// for a staff account who is also a real SHG member seeing (and, before
/// that round, being able to actually approve) her own pending application
/// in the platform-wide review queue.
///
/// This can't be exercised through the real page in a widget test:
/// `AppState.profile` only ever gets set via a live-mode profile
/// upsert/fetch (`upsertMyProfile`/`fetchMyProfile`, both hard-requiring a
/// real Supabase session) — even after `completeProfileSetup()` in demo
/// mode, `profile` stays `null` (demo mode tracks identity via separate
/// legacy name/role fields instead). Since the review page's `myId` comes
/// from `context.watch<AppState>().profile?.id`, a demo-mode widget test
/// can never make `myId` equal a specific pending application's
/// `memberId` to prove the exclusion actually fires — the same class of
/// demo-mode/live-mode architecture conflict already disclosed for
/// `loan_detail_page.dart`'s Record Payment dialog. This isolates the
/// exact filter expression instead, mirroring
/// `double_submit_guard_pattern_test.dart`'s technique for a pattern that
/// can't be forced through the real page.
void main() {
  SchemeApplicationReview app(String id, String memberId) => SchemeApplicationReview(
        applicationId: id,
        schemeId: 'sc$id',
        schemeName: 'Scheme $id',
        memberId: memberId,
        memberName: 'Member $memberId',
        status: 'applied',
        appliedOn: DateTime(2026, 1, 1),
      );

  test('the viewer\'s own pending application is excluded from the review queue', () {
    final allApps = [app('1', 'staff-1'), app('2', 'other-member'), app('3', 'staff-1')];
    const myId = 'staff-1';

    final visible = allApps.where((a) => a.memberId != myId).toList();

    expect(visible.map((a) => a.applicationId), ['2']);
  });

  test('a viewer with no pending application of her own sees every row unfiltered', () {
    final allApps = [app('1', 'member-a'), app('2', 'member-b')];
    const myId = 'staff-1';

    final visible = allApps.where((a) => a.memberId != myId).toList();

    expect(visible.length, 2);
  });

  test('a null viewer id (the only value reachable via demo mode\'s AppState.profile) excludes nothing, since no real application ever has a null memberId', () {
    final allApps = [app('1', 'demo-member'), app('2', 'demo-member')];
    const String? myId = null;

    final visible = allApps.where((a) => a.memberId != myId).toList();

    expect(visible.length, 2, reason: 'documents the demo-mode baseline this module\'s widget tests are actually limited to — see this file\'s doc comment');
  });
}
