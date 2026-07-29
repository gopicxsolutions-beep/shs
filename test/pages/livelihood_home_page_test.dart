import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/models/livelihood.dart';
import 'package:shg_saathi/models/profile.dart';
import 'package:shg_saathi/pages/livelihood/livelihood_home_page.dart';
import 'package:shg_saathi/repositories/livelihood_repository.dart';
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

/// Canned cross-SHG data — avoids a real network call in a test environment
/// with no live backend, mirroring loans_home_page_test.dart's
/// `_FakePlatformWideLoanRepository`.
class _FakePlatformWideLivelihoodRepository extends LivelihoodRepository {
  @override
  Future<List<LivelihoodActivity>> fetchAllForStaff() async => const [
        LivelihoodActivity(id: 'act-1', shgId: 'shg-1', memberId: 'mem-1', memberName: 'Test Member One', activityType: 'Dairy', investment: 1000, revenue: 1500, status: 'active', shgName: 'Jyothi SHG'),
        LivelihoodActivity(id: 'act-2', shgId: 'shg-2', memberId: 'mem-2', memberName: 'Test Member Two', activityType: 'Tailoring', investment: 500, revenue: 200, status: 'active', shgName: 'Sneha SHG'),
      ];
  @override
  Future<List<LivelihoodActivity>> fetchForMember(String? memberId) async => const [];
  @override
  Future<List<LivelihoodActivity>> fetchForShg(String? shgId) async => const [];
}

/// Round 168 (Loans/Savings) fix template applied to Livelihood: crp/clf/
/// admin (no `shgId` of their own) used to see round-146-style honest
/// "doesn't apply" message — now a real platform-wide activity feed, since
/// `livelihood_select_shg_or_staff` already grants `is_staff()` unrestricted
/// platform-wide read.
void main() {
  Future<void> boot(WidgetTester tester, AppState appState, {LivelihoodRepository? repository}) async {
    SharedPreferences.setMockInitialValues(const {});
    await appState.init();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          home: LivelihoodHomePage(repository: repository),
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

  group('live mode — staff-with-no-linked-SHG platform-wide feed (round 168)', () {
    setUp(() {
      SupabaseService.isConfigured = true;
    });
    tearDown(() {
      SupabaseService.isConfigured = false;
    });

    for (final staffRole in ['crp', 'clf', 'admin']) {
      testWidgets('a $staffRole account with no linked SHG sees a real cross-SHG feed, not the old dead-end message', (tester) async {
        final profile = Profile(id: 'staff-$staffRole', name: 'QA $staffRole', role: staffRole, shgId: null);
        final appState = AppState(
          profileRepository: _FixedProfileRepository(profile),
          authService: _FakeAuthServiceWithSession(),
        );

        await boot(tester, appState, repository: _FakePlatformWideLivelihoodRepository());

        expect(find.text("Your role isn't linked to a specific SHG — this view doesn't apply"), findsNothing);
        expect(find.text('Test Member One · Jyothi SHG'), findsOneWidget, reason: 'each row must show which SHG it belongs to');
        expect(find.text('Test Member Two · Sneha SHG'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a leader account with a real linked SHG sees plain member names, not SHG-tagged ones', (tester) async {
      const profile = Profile(id: 'leader-1', name: 'QA Leader', role: 'leader', shgId: 'shg-1');
      final appState = AppState(
        profileRepository: _FixedProfileRepository(profile),
        authService: _FakeAuthServiceWithSession(),
      );

      await boot(tester, appState, repository: _FakePlatformWideLivelihoodRepository());

      expect(find.text("Your role isn't linked to a specific SHG — this view doesn't apply"), findsNothing);
      expect(find.textContaining(' · '), findsNothing, reason: 'a leader only ever sees her own SHG, so the SHG tag would be redundant noise');
      expect(tester.takeException(), isNull);
    });
  });
}
