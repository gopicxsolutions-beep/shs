import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/models/profile.dart';
import 'package:shg_saathi/pages/savings/savings_home_page.dart';
import 'package:shg_saathi/services/auth_service.dart';
import 'package:shg_saathi/services/profile_repository.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/state/app_state.dart';

class _FixedProfileRepository extends ProfileRepository {
  _FixedProfileRepository(this._profile);
  final Profile? _profile;
  @override
  Future<Profile?> fetchMyProfile() async => _profile;
}

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

/// Regression coverage for round 146's fix: `SavingsHomePage` used to
/// resolve "which SHG" from `appState.profile?.shgId` unconditionally in
/// live mode — always null for crp/clf/admin (platform-wide roles, never
/// SHG-scoped) — so a staff account saw the stat cards/tile row/recent-
/// entries list all render as if the SHG genuinely had zero savings,
/// indistinguishable from an honest empty state. The fix added an early
/// guard: `isConfigured && isLeaderOrStaff && shgId == null` now shows an
/// explicit "this per-SHG view doesn't apply to your role" message instead.
/// `flutter test`'s existing 969-test suite never exercises this branch at
/// all (`SupabaseService.isConfigured` is false by construction, since no
/// test boots a real Supabase client), so passing the full suite only ever
/// proved "demo mode is unaffected" — this file is what actually exercises
/// the new guard, live-mode-simulated via the same `isConfigured = true` +
/// fake `ProfileRepository` pattern already established in
/// shg_documents_page_test.dart.
void main() {
  Future<void> boot(WidgetTester tester, AppState appState) async {
    SharedPreferences.setMockInitialValues(const {});
    await appState.init();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          home: const SavingsHomePage(),
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
  }

  group('live mode — staff-with-no-linked-SHG guard', () {
    setUp(() {
      SupabaseService.isConfigured = true;
    });
    tearDown(() {
      SupabaseService.isConfigured = false;
    });

    for (final staffRole in ['crp', 'clf', 'admin']) {
      testWidgets('a $staffRole account with no linked SHG sees the honest "doesn\'t apply" message, not broken stat cards', (tester) async {
        final profile = Profile(id: 'staff-$staffRole', name: 'QA $staffRole', role: staffRole, shgId: null);
        final appState = AppState(
          profileRepository: _FixedProfileRepository(profile),
          authService: _FakeAuthServiceWithSession(),
        );

        await boot(tester, appState);

        expect(find.text("Your role isn't linked to a specific SHG — this view doesn't apply"), findsOneWidget);
        // The guard replaces the ENTIRE body — none of the normal page's
        // stat-card/tile-row content should be present alongside it.
        expect(find.text('Group Savings'), findsNothing);
        expect(find.text('Ledger'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a leader account with a real linked SHG does not see the guard message', (tester) async {
      const profile = Profile(id: 'leader-1', name: 'QA Leader', role: 'leader', shgId: 'shg-1');
      final appState = AppState(
        profileRepository: _FixedProfileRepository(profile),
        authService: _FakeAuthServiceWithSession(),
      );

      await boot(tester, appState);

      expect(find.text("Your role isn't linked to a specific SHG — this view doesn't apply"), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a member account with no linked SHG does not see the staff guard either — the guard is staff-specific, not a bare null-shgId check', (tester) async {
      const profile = Profile(id: 'member-1', name: 'QA Member', role: 'member', shgId: null);
      final appState = AppState(
        profileRepository: _FixedProfileRepository(profile),
        authService: _FakeAuthServiceWithSession(),
      );

      await boot(tester, appState);

      expect(find.text("Your role isn't linked to a specific SHG — this view doesn't apply"), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
