import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shg_saathi/models/profile.dart';
import 'package:shg_saathi/models/shg.dart';
import 'package:shg_saathi/repositories/shg_join_request_repository.dart';
import 'package:shg_saathi/repositories/shg_repository.dart';
import 'package:shg_saathi/services/auth_service.dart';
import 'package:shg_saathi/services/profile_repository.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/state/app_state.dart';

/// Fakes override every method that would otherwise reach a live Supabase
/// client, so these never touch `SupabaseService.instance`.
class _FakeProfileRepository extends ProfileRepository {
  _FakeProfileRepository(this._responses, {this._upsertResponse});
  final List<Future<Profile?> Function()> _responses;
  final Profile? _upsertResponse;
  int _calls = 0;

  @override
  Future<Profile?> fetchMyProfile() => _responses[_calls++]();

  @override
  Future<Profile> upsertMyProfile({required String name, String? mobile, String role = 'member', String? shgId, String? village}) async => _upsertResponse!;
}

class _FakeAuthService extends AuthService {
  @override
  Future<void> signOut() async {}
}

/// Drives a controllable [onAuthStateChange] stream so tests can push
/// specific [AuthChangeEvent]s (e.g. `tokenRefreshed`) at [AppState] without
/// touching a live Supabase client.
class _FakeAuthServiceWithStream extends AuthService {
  _FakeAuthServiceWithStream(this._initialSession);
  final Session? _initialSession;
  final _controller = StreamController<AuthState>.broadcast();
  Session? _currentSession;

  @override
  Session? get currentSession => _currentSession ??= _initialSession;

  @override
  Stream<AuthState> get onAuthStateChange => _controller.stream;

  @override
  Future<void> signOut() async {}

  void emit(AuthChangeEvent event, Session? session) {
    _currentSession = session;
    _controller.add(AuthState(event, session));
  }
}

Session _fakeSession(String userId) => Session(
      accessToken: 'token-$userId',
      tokenType: 'bearer',
      refreshToken: 'refresh-$userId',
      user: User(id: userId, appMetadata: const {}, userMetadata: const {}, aud: 'authenticated', createdAt: DateTime(2026).toIso8601String()),
    );

class _FakeShgRepository extends ShgRepository {
  _FakeShgRepository(this._shg);
  final ShgProfile? _shg;

  @override
  Future<ShgProfile?> fetchShg(String? shgId) async => _shg;
}

void main() {
  setUp(() {
    SupabaseService.isConfigured = true;
    SharedPreferences.setMockInitialValues({});
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

  group('AppState.profileLoadFailedNetwork', () {
    // Covers the round-67-diagnosed bug: a returning, already-onboarded
    // user whose session restores locally (no network needed) but whose
    // very first profile fetch this session fails offline used to be
    // silently misrouted to Profile Setup, indistinguishable from a
    // brand-new user. These tests pin the flag the router now reads to
    // route that case differently — see routes/router.dart's `redirect`.
    test('a network failure on the very first profile load sets the flag, and hasProfile stays false', () async {
      final fakeRepo = _FakeProfileRepository([() => Future<Profile?>.error(TimeoutException('timed out'))]);
      final appState = AppState(profileRepository: fakeRepo, authService: _FakeAuthService(), joinRequestRepository: ShgJoinRequestRepository());

      await appState.refreshProfile();

      expect(appState.hasProfile, isFalse);
      expect(appState.profileLoadFailedNetwork, isTrue, reason: 'a TimeoutException on the first-ever load is a connectivity failure, not a confirmed empty profile');
    });

    test('a confirmed empty profile (server returns null, no error) does not set the flag', () async {
      final fakeRepo = _FakeProfileRepository([() async => null]);
      final appState = AppState(profileRepository: fakeRepo, authService: _FakeAuthService(), joinRequestRepository: ShgJoinRequestRepository());

      await appState.refreshProfile();

      expect(appState.hasProfile, isFalse);
      expect(appState.profileLoadFailedNetwork, isFalse, reason: 'a genuinely new user (server confirms zero rows) must still be routed to Profile Setup, not the retry screen');
    });

    test('a non-network error on the first load does not set the flag', () async {
      final fakeRepo = _FakeProfileRepository([() => Future<Profile?>.error(Exception('permission denied'))]);
      final appState = AppState(profileRepository: fakeRepo, authService: _FakeAuthService(), joinRequestRepository: ShgJoinRequestRepository());

      await appState.refreshProfile();

      expect(appState.profileLoadFailedNetwork, isFalse, reason: 'only the specific isNetworkError detection (TimeoutException/http.ClientException) should set this flag');
    });

    test('the flag clears once a retry succeeds', () async {
      const profile = Profile(id: 'p1', name: 'Asha', role: 'member');
      final fakeRepo = _FakeProfileRepository([
        () => Future<Profile?>.error(TimeoutException('timed out')),
        () async => profile,
      ]);
      final appState = AppState(profileRepository: fakeRepo, authService: _FakeAuthService(), joinRequestRepository: ShgJoinRequestRepository());

      await appState.refreshProfile();
      expect(appState.profileLoadFailedNetwork, isTrue);

      await appState.refreshProfile();
      expect(appState.profileLoadFailedNetwork, isFalse, reason: 'a successful retry must clear the flag so the router lets the user through to their dashboard');
      expect(appState.hasProfile, isTrue);
    });

    test('a network failure refreshing an already-loaded profile does not set the flag (hasProfile stays true throughout)', () async {
      const profile = Profile(id: 'p1', name: 'Asha', role: 'member');
      final fakeRepo = _FakeProfileRepository([
        () async => profile,
        () => Future<Profile?>.error(TimeoutException('timed out')),
      ]);
      final appState = AppState(profileRepository: fakeRepo, authService: _FakeAuthService(), joinRequestRepository: ShgJoinRequestRepository());

      await appState.refreshProfile();
      expect(appState.hasProfile, isTrue);

      await appState.refreshProfile();
      expect(appState.hasProfile, isTrue, reason: 'the existing "leave previously-loaded profile in place" behavior must be unaffected');
      expect(appState.profileLoadFailedNetwork, isFalse, reason: 'the router only ever reads this flag while !hasProfile, so it must stay false once a profile has been loaded');
    });

    test('signOut clears the flag', () async {
      final fakeRepo = _FakeProfileRepository([() => Future<Profile?>.error(TimeoutException('timed out'))]);
      final appState = AppState(profileRepository: fakeRepo, authService: _FakeAuthService(), joinRequestRepository: ShgJoinRequestRepository());

      await appState.refreshProfile();
      expect(appState.profileLoadFailedNetwork, isTrue);

      await appState.signOut();
      expect(appState.profileLoadFailedNetwork, isFalse, reason: 'a stale network-failure flag must not survive into a fresh, unauthenticated state');
    });
  });

  group('AppState pending deep link', () {
    // Covers the round-66/68-diagnosed gap: an unauthenticated deep link
    // used to lose its target entirely once bounced to the splash screen.
    // The router now captures it here (see routes/router.dart's `redirect`)
    // for OtpPage to replay after a successful sign-in.
    test('capture then consume returns the captured location and clears it (single-use)', () {
      final appState = AppState(profileRepository: _FakeProfileRepository([]), authService: _FakeAuthService(), joinRequestRepository: ShgJoinRequestRepository());

      expect(appState.pendingDeepLink, isNull);
      appState.capturePendingDeepLink('/app/loans/abc123');
      expect(appState.pendingDeepLink, '/app/loans/abc123');

      expect(appState.consumePendingDeepLink(), '/app/loans/abc123');
      expect(appState.pendingDeepLink, isNull, reason: 'consuming must clear it so it cannot be replayed a second time');
      expect(appState.consumePendingDeepLink(), isNull);
    });

    test('a later capture overwrites an earlier, never-consumed one', () {
      final appState = AppState(profileRepository: _FakeProfileRepository([]), authService: _FakeAuthService(), joinRequestRepository: ShgJoinRequestRepository());

      appState.capturePendingDeepLink('/app/loans/abc123');
      appState.capturePendingDeepLink('/app/schemes/xyz789');

      expect(appState.consumePendingDeepLink(), '/app/schemes/xyz789', reason: 'only the most recent deep-link attempt should ever be replayed');
    });

    test('signOut clears a captured but never-consumed deep link', () async {
      final appState = AppState(profileRepository: _FakeProfileRepository([]), authService: _FakeAuthService(), joinRequestRepository: ShgJoinRequestRepository());
      appState.capturePendingDeepLink('/app/loans/abc123');

      await appState.signOut();

      expect(appState.pendingDeepLink, isNull, reason: 'a stale deep link must not survive into a fresh sign-in as a possibly-different account');
    });
  });

  group('AppState._authSub token-refresh handling', () {
    test('a tokenRefreshed event does not re-fetch the profile (only initialSession/signedIn/etc. do)', () async {
      final session = _fakeSession('u1');
      final fakeAuth = _FakeAuthServiceWithStream(session);
      var fetchCount = 0;
      final fakeRepo = _FakeProfileRepository([
        () async {
          fetchCount++;
          return const Profile(id: 'u1', name: 'Asha', role: 'member');
        },
      ]);
      final appState = AppState(profileRepository: fakeRepo, authService: fakeAuth, joinRequestRepository: ShgJoinRequestRepository(), shgRepository: _FakeShgRepository(null));

      await appState.init();
      expect(fetchCount, 1, reason: 'the initial session load should fetch the profile once');

      // GoTrue's auto-refresh timer fires this roughly hourly purely to
      // rotate the JWT — it must not re-trigger a profile/SHG refetch.
      fakeAuth.emit(AuthChangeEvent.tokenRefreshed, _fakeSession('u1'));
      await Future<void>.delayed(Duration.zero);
      expect(fetchCount, 1, reason: 'a routine token refresh must not re-fetch the profile');
      expect(appState.profile?.id, 'u1');

      appState.dispose();
    });

    test('a signedIn event after tokenRefreshed still re-fetches the profile', () async {
      final session = _fakeSession('u1');
      final fakeAuth = _FakeAuthServiceWithStream(session);
      var fetchCount = 0;
      final fakeRepo = _FakeProfileRepository([
        () async {
          fetchCount++;
          return const Profile(id: 'u1', name: 'Asha', role: 'member');
        },
        () async {
          fetchCount++;
          return const Profile(id: 'u1', name: 'Asha', role: 'member');
        },
      ]);
      final appState = AppState(profileRepository: fakeRepo, authService: fakeAuth, joinRequestRepository: ShgJoinRequestRepository(), shgRepository: _FakeShgRepository(null));

      await appState.init();
      expect(fetchCount, 1);

      fakeAuth.emit(AuthChangeEvent.signedIn, _fakeSession('u1'));
      await Future<void>.delayed(Duration.zero);
      expect(fetchCount, 2, reason: 'non-refresh auth events must still refetch the profile');

      appState.dispose();
    });

    test('a signedOut event (e.g. an invalid/expired refresh token) clears the profile so the router redirects to login', () async {
      final session = _fakeSession('u1');
      final fakeAuth = _FakeAuthServiceWithStream(session);
      final fakeRepo = _FakeProfileRepository([() async => const Profile(id: 'u1', name: 'Asha', role: 'member')]);
      final appState = AppState(profileRepository: fakeRepo, authService: fakeAuth, joinRequestRepository: ShgJoinRequestRepository(), shgRepository: _FakeShgRepository(null));

      await appState.init();
      expect(appState.hasSession, isTrue);
      expect(appState.hasProfile, isTrue);

      fakeAuth.emit(AuthChangeEvent.signedOut, null);
      await Future<void>.delayed(Duration.zero);
      expect(appState.hasSession, isFalse);
      expect(appState.hasProfile, isFalse, reason: 'local profile state must be cleared so the router redirect (!hasSession) takes the user to login instead of leaving stale UI up');

      appState.dispose();
    });
  });

  group('AppState SHG name & role-selection persistence', () {
    test('user.shgName reflects the fetched SHG, not the onboarding-time pick or the default placeholder', () async {
      const profile = Profile(id: 'p1', name: 'Asha', role: 'member', shgId: 'shg-1');
      final fakeRepo = _FakeProfileRepository([() async => profile]);
      final fakeShgRepo = _FakeShgRepository(const ShgProfile(id: 'shg-1', name: 'Real SHG Name'));
      final appState = AppState(
        profileRepository: fakeRepo,
        authService: _FakeAuthService(),
        joinRequestRepository: ShgJoinRequestRepository(),
        shgRepository: fakeShgRepo,
      );

      await appState.refreshProfile();

      expect(appState.user.shgName, 'Real SHG Name');
    });

    test('needsRoleSelection survives a fresh AppState instance for the same profile (app restart before Role Select)', () async {
      const profile = Profile(id: 'p2', name: 'Latha', role: 'member');
      final firstAppState = AppState(
        profileRepository: _FakeProfileRepository([() async => profile], upsertResponse: profile),
        authService: _FakeAuthService(),
        joinRequestRepository: ShgJoinRequestRepository(),
        shgRepository: _FakeShgRepository(null),
      );
      await firstAppState.completeProfileSetup(name: 'Latha', village: 'Village');
      expect(firstAppState.needsRoleSelection, isTrue);

      // Simulate an app restart: a brand-new AppState re-fetches the same
      // profile row. Without persisting the pending flag, this fresh
      // instance's in-memory default (false) would strand the user on
      // ShgApprovalPendingPage instead of restoring them to Role Select.
      final secondAppState = AppState(
        profileRepository: _FakeProfileRepository([() async => profile]),
        authService: _FakeAuthService(),
        joinRequestRepository: ShgJoinRequestRepository(),
        shgRepository: _FakeShgRepository(null),
      );
      await secondAppState.refreshProfile();

      expect(secondAppState.needsRoleSelection, isTrue, reason: 'role-selection-pending must survive a reload, not just live in memory');
    });
  });
}
