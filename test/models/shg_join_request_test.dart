import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/models/shg_join_request.dart';

/// Regression coverage for the "My SHG" module audit (round 89): a pending
/// requester's `profiles.shg_id` stays null until approval (see
/// AppState.completeProfileSetup), so `profiles_select_self_shg_or_staff`
/// could never resolve the `profiles(name)` embed in
/// `ShgJoinRequestRepository.fetchPendingForShg()` for a leader — every
/// join-request card silently fell back to the generic "Member" label.
/// Migration 0045 adds `profiles_select_pending_join_requester` to close
/// that gap and the repository now also requests `mobile`, so a leader can
/// distinguish two same-named requesters before approving. This covers the
/// pure `fromMap` parsing side of that fix; the RLS half is only
/// verifiable against a live project (see migration 0045's own header).
void main() {
  test('ShgJoinRequest.fromMap parses memberName and memberMobile from the embedded profiles relation', () {
    final r = ShgJoinRequest.fromMap({
      'id': 'r1',
      'member_id': 'm1',
      'shg_id': 'shg1',
      'status': 'pending',
      'requested_at': '2026-07-20T20:30:00Z',
      'profiles': {'name': 'Priya Reddy', 'mobile': '9876543210'},
    });
    expect(r.memberName, 'Priya Reddy');
    expect(r.memberMobile, '9876543210');
  });

  test('ShgJoinRequest.fromMap leaves memberName/memberMobile null when the profiles embed is absent (RLS-denied)', () {
    // Mirrors exactly what a real RLS-denied embed looks like: PostgREST
    // returns the relation as null rather than erroring the whole query,
    // which is precisely why this bug was invisible in casual testing --
    // the page never crashed, it just always showed the generic fallback.
    final r = ShgJoinRequest.fromMap({
      'id': 'r1',
      'member_id': 'm1',
      'shg_id': 'shg1',
      'status': 'pending',
      'requested_at': '2026-07-20T20:30:00Z',
      'profiles': null,
    });
    expect(r.memberName, isNull);
    expect(r.memberMobile, isNull);
  });
}
