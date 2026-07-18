import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/models/profile.dart';
import 'package:shg_saathi/repositories/shg_join_request_repository.dart';
import 'package:shg_saathi/services/auth_service.dart';
import 'package:shg_saathi/services/profile_repository.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/state/app_state.dart';

/// Fakes override every method that would otherwise reach a live Supabase
/// client, so these never touch `SupabaseService.instance`.
class _FakeProfileRepository extends ProfileRepository {
  _FakeProfileRepository(this._responses);
  final List<Future<Profile?> Function()> _responses;
  int _calls = 0;

  @override
  Future<Profile?> fetchMyProfile() => _responses[_calls++]();
}

class _FakeAuthService extends AuthService {
  @override
  Future<void> signOut() async {}
}

void main() {
  setUp(() {
    SupabaseService.isConfigured = true;
  });

  tearDown(() {
    SupabaseService.isConfigured = false;
  });

  group('AppState._loadProfile generation guard', () {
    test('a slower stale profile fetch does not clobber a newer one', () async {
      final slowCompleter = Completer<Profile?>();
      const freshProfile = Profile(id: 'new', name: 'Fresh', role: 'member');
      final fakeRepo = _FakeProfileRepository([
        () => slowCompleter.future,
        () async => freshProfile,
      ]);
      final appState = AppState(profileRepository: fakeRepo, authService: _FakeAuthService(), joinRequestRepository: ShgJoinRequestRepository());

      final firstCall = appState.refreshProfile();
      final secondCall = appState.refreshProfile();
      await secondCall;
      expect(appState.profile?.id, 'new');

      slowCompleter.complete(const Profile(id: 'old', name: 'Stale', role: 'member'));
      await firstCall;
      expect(appState.profile?.id, 'new', reason: 'the stale slower fetch must not overwrite the newer profile');
    });

    test('signOut wins over a slower in-flight profile fetch', () async {
      final slowCompleter = Completer<Profile?>();
      final fakeRepo = _FakeProfileRepository([() => slowCompleter.future]);
      final appState = AppState(profileRepository: fakeRepo, authService: _FakeAuthService(), joinRequestRepository: ShgJoinRequestRepository());

      final refreshFuture = appState.refreshProfile();
      await appState.signOut();
      expect(appState.profile, isNull);

      slowCompleter.complete(const Profile(id: 'stale', name: 'Stale', role: 'member'));
      await refreshFuture;
      expect(appState.profile, isNull, reason: 'a fetch in flight before sign-out must not repopulate the profile afterward');
    });

    test('a transient fetch failure leaves a previously-loaded profile in place', () async {
      const initialProfile = Profile(id: 'keep-me', name: 'Existing', role: 'member');
      final fakeRepo = _FakeProfileRepository([
        () async => initialProfile,
        () => Future<Profile?>.error(Exception('network error')),
      ]);
      final appState = AppState(profileRepository: fakeRepo, authService: _FakeAuthService(), joinRequestRepository: ShgJoinRequestRepository());

      await appState.refreshProfile();
      expect(appState.profile?.id, 'keep-me');

      await appState.refreshProfile();
      expect(appState.profile?.id, 'keep-me', reason: 'a failed refresh should not wipe a valid, already-loaded profile');
    });
  });
}
