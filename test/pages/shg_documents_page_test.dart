import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/models/profile.dart';
import 'package:shg_saathi/pages/profile/profile_page.dart';
import 'package:shg_saathi/pages/shg/shg_documents_page.dart';
import 'package:shg_saathi/services/auth_service.dart';
import 'package:shg_saathi/services/profile_repository.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/state/app_state.dart';

/// A profile-repository fake that always returns the same fixed [Profile] —
/// used to drive `AppState` in *live* mode (unlike the rest of this file's
/// tests, which boot through the demo-mode legacy SharedPreferences flags).
class _FixedProfileRepository extends ProfileRepository {
  _FixedProfileRepository(this._profile);
  final Profile? _profile;
  @override
  Future<Profile?> fetchMyProfile() async => _profile;
}

/// A profile-repository fake whose `fetchMyProfile()` doesn't resolve until
/// the caller completes [future] — lets a test observe `ShgDocumentsPage`
/// *while* the profile fetch is still in flight, then complete it and check
/// the already-mounted page updates reactively (see the "stale widget tree"
/// hypothesis test below).
class _DelayedProfileRepository extends ProfileRepository {
  _DelayedProfileRepository(this._future);
  final Future<Profile?> _future;
  @override
  Future<Profile?> fetchMyProfile() => _future;
}

/// Supplies a non-null `currentSession` so `AppState.init()` takes the
/// "session exists, fetch the profile" branch, without ever touching a real
/// Supabase client.
class _FakeAuthServiceWithSession extends AuthService {
  @override
  Session? get currentSession => Session(
        accessToken: 'token',
        tokenType: 'bearer',
        refreshToken: 'refresh',
        user: User(id: 'u1', appMetadata: const {}, userMetadata: const {}, aud: 'authenticated', createdAt: DateTime(2026).toIso8601String()),
      );

  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();
}

/// Regression coverage for the real file-upload wiring added to the
/// "Add document" dialog — a file is now required (not just a name), and
/// the previously-decorative download icon now actually opens a document.
/// Neither test taps the "Choose file" control itself, since that invokes
/// `file_picker`'s real platform channel (unavailable/unmocked under
/// `flutter test`, same class of limitation already documented for the
/// camera QR scanner and voice mic) — instead these cover the validation
/// and no-file-attached paths, which are pure Flutter/Dart logic reachable
/// without ever opening the OS file picker.
void main() {
  Future<void> boot(WidgetTester tester, Map<String, Object> prefs, {AppState? appStateOverride}) async {
    SharedPreferences.setMockInitialValues(prefs);
    final appState = appStateOverride ?? AppState();
    await appState.init();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          home: const ShgDocumentsPage(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('confirming Add Document without choosing a file shows a validation message, not a silent no-op', (tester) async {
    await boot(tester, const {'shg_session_started': true, 'shg_authenticated': true, 'shg_role': 'leader'});

    await tester.tap(find.byTooltip('Add document'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Bylaws copy');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Please choose a file to upload.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a document with no attached file shows a helpful message instead of trying to open nothing', (tester) async {
    // Demo mode's mock documents (lib/data/shg.dart) predate this feature
    // and carry no storagePath — this is the same state a real pre-existing
    // metadata-only production row would be in.
    await boot(tester, const {});

    await tester.tap(find.byIcon(Icons.download_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('No file is attached to this record.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('live mode — "Add document" visibility follows the real profiles.role, regardless of SHG linkage', () {
    // Root-cause investigation for a live-testing report: a persisted
    // "QA Leader" account (Profile page correctly shows the "SHG Leader /
    // President" badge, so its real stored `profiles.role` is genuinely
    // 'leader') did not see the "Add document" (+) button here, even though
    // this button's gate — `appState.user.role != Role.member` — depends
    // only on role, not on SHG linkage.
    //
    // These tests drive `AppState` in *live* mode (`SupabaseService.
    // isConfigured = true`, a fake `ProfileRepository` standing in for the
    // real `profiles` table fetch — see `_FixedProfileRepository` above)
    // with a profile whose `role` string is exactly what `AppState.setRole`/
    // `AdminRepository.updateUserRole` would have written for a real leader
    // account, then assert the button renders. If this passes, the
    // `Role.values.where((r) => r.name == _profile!.role)` derivation in
    // `AppState.user` and the `isLeaderOrStaff` gate in
    // `ShgDocumentsPage.build()` are both provably correct for a genuine
    // leader account — which means a real leader seeing this bug is not
    // explained by anything reachable from this code path, and points
    // instead at that one account's `profiles.role` column holding a value
    // that doesn't string-match `Role.leader.name` (`'leader'`) — a data
    // anomaly on that specific row, not a reproducible app bug. See
    // `AppState.user`'s doc-adjacent fallback-to-member behavior.
    setUp(() {
      SupabaseService.isConfigured = true;
    });
    tearDown(() {
      SupabaseService.isConfigured = false;
    });

    testWidgets('a leader account not linked to any SHG (shgId null) still sees the Add document button', (tester) async {
      const profile = Profile(id: 'leader-1', name: 'QA Leader', role: 'leader', shgId: null);
      final appState = AppState(
        profileRepository: _FixedProfileRepository(profile),
        authService: _FakeAuthServiceWithSession(),
      );

      await boot(tester, const {}, appStateOverride: appState);

      expect(appState.user.role.name, 'leader', reason: 'sanity check: the role-derivation getter under test must actually resolve to leader here');
      expect(find.byTooltip('Add document'), findsOneWidget);
    });

    testWidgets('a leader account linked to an SHG also sees the Add document button', (tester) async {
      const profile = Profile(id: 'leader-2', name: 'QA Leader', role: 'leader', shgId: 'shg-1');
      final appState = AppState(
        profileRepository: _FixedProfileRepository(profile),
        authService: _FakeAuthServiceWithSession(),
      );

      await boot(tester, const {}, appStateOverride: appState);

      expect(find.byTooltip('Add document'), findsOneWidget);
    });

    for (final staffRole in ['crp', 'clf', 'admin']) {
      testWidgets('a $staffRole account sees the Add document button too (staff, not just leader)', (tester) async {
        final profile = Profile(id: 'staff-$staffRole', name: 'QA $staffRole', role: staffRole, shgId: null);
        final appState = AppState(
          profileRepository: _FixedProfileRepository(profile),
          authService: _FakeAuthServiceWithSession(),
        );

        await boot(tester, const {}, appStateOverride: appState);

        expect(find.byTooltip('Add document'), findsOneWidget);
      });
    }

    testWidgets('a genuine member account does not see the Add document button', (tester) async {
      const profile = Profile(id: 'member-1', name: 'QA Member', role: 'member', shgId: 'shg-1');
      final appState = AppState(
        profileRepository: _FixedProfileRepository(profile),
        authService: _FakeAuthServiceWithSession(),
      );

      await boot(tester, const {}, appStateOverride: appState);

      expect(find.byTooltip('Add document'), findsNothing);
    });

    testWidgets('an unrecognized profiles.role string silently falls back to member and hides the button — the actual data-anomaly failure mode', (tester) async {
      // This is the one input that reproduces "role badge looks fine
      // elsewhere, Add document button missing here" — but note it requires
      // `profiles.role` to hold a string that isn't any `Role.name`, which
      // would ALSO make `roleInfoFor(user.role).label` on the Profile page
      // fall back to "SHG Member", not show "SHG Leader / President". So
      // this data anomaly does not match what was actually observed live —
      // documented here to make that distinction explicit and testable.
      const profile = Profile(id: 'weird-1', name: 'QA Weird', role: 'Leader', shgId: null); // capitalized — does not match Role.leader.name ('leader')
      final appState = AppState(
        profileRepository: _FixedProfileRepository(profile),
        authService: _FakeAuthServiceWithSession(),
      );

      await boot(tester, const {}, appStateOverride: appState);

      expect(appState.user.role.name, 'member', reason: 'an unmatched role string silently falls back to Role.member (see AppState.user)');
      expect(find.byTooltip('Add document'), findsNothing);
    });

    testWidgets(
      "the Add document button's visibility is provably consistent with the Profile page's own role badge for the exact same account — the precise 'Profile looks right, Documents does not' scenario reported live",
      (tester) async {
        const profile = Profile(id: 'leader-3', name: 'QA Leader', role: 'leader', shgId: null);
        final appState = AppState(
          profileRepository: _FixedProfileRepository(profile),
          authService: _FakeAuthServiceWithSession(),
        );
        SharedPreferences.setMockInitialValues(const {});
        await appState.init();

        const delegates = [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ];

        // Render the Profile page first, with this exact AppState instance,
        // and confirm it shows the same badge the live report described.
        await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(home: const ProfilePage(), localizationsDelegates: delegates, supportedLocales: AppLocalizations.supportedLocales),
        ));
        await tester.pumpAndSettle();
        expect(find.text('SHG Leader / President'), findsOneWidget);

        // Now render ShgDocumentsPage with the SAME AppState instance (same
        // profile, same point in time) — it must also show the button.
        // Both reads go through the identical `appState.user.role`, so
        // these two can never legitimately disagree for one account at one
        // moment; if this assertion ever fails, that's the real bug.
        await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(home: const ShgDocumentsPage(), localizationsDelegates: delegates, supportedLocales: AppLocalizations.supportedLocales),
        ));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Add document'), findsOneWidget);
      },
    );

    testWidgets(
      'the Add document button appears reactively once the leader profile finishes loading, with no need to leave and re-enter the page — rules out a stale-widget-tree explanation',
      (tester) async {
        final pending = Completer<Profile?>();
        final appState = AppState(
          profileRepository: _DelayedProfileRepository(pending.future),
          authService: _FakeAuthServiceWithSession(),
        );
        SharedPreferences.setMockInitialValues(const {});
        unawaited(appState.init()); // deliberately not awaited: the profile fetch below is still in flight when the page first mounts.

        await tester.pumpWidget(
          ChangeNotifierProvider<AppState>.value(
            value: appState,
            child: MaterialApp(
              home: const ShgDocumentsPage(),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pump();

        // Profile hasn't resolved yet — `appState.user` falls back to
        // `defaultUser` (Role.member) — button correctly hidden for now.
        expect(find.byTooltip('Add document'), findsNothing);

        pending.complete(const Profile(id: 'leader-4', name: 'QA Leader', role: 'leader', shgId: null));
        await tester.pumpAndSettle();

        // Same mounted widget, same BuildContext, no navigation away and
        // back — `context.watch<AppState>()` must pick up the profile load
        // completing and rebuild on its own.
        expect(find.byTooltip('Add document'), findsOneWidget);
      },
    );
  });
}
