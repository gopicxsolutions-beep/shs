import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/models/profile.dart';
import 'package:shg_saathi/models/savings.dart';
import 'package:shg_saathi/pages/savings/savings_home_page.dart';
import 'package:shg_saathi/repositories/savings_repository.dart';
import 'package:shg_saathi/services/auth_service.dart';
import 'package:shg_saathi/services/profile_repository.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/state/app_state.dart';

class _FixedProfileRepository extends ProfileRepository {
  _FixedProfileRepository(this._profile);
  final Profile? _profile;
  @override
  Future<Profile?> fetchMyProfile(String? uid) async => _profile;
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
class _FakePlatformWideSavingsRepository extends SavingsRepository {
  @override
  Future<List<SavingsEntry>> fetchAllForStaff() async => [
        SavingsEntry(id: 'entry-1', memberId: 'mem-1', memberName: 'Test Member One', date: DateTime(2026, 6, 1), amount: 500, mode: 'Cash', frequency: 'Monthly', status: 'verified', shgName: 'Jyothi SHG'),
        SavingsEntry(id: 'entry-2', memberId: 'mem-2', memberName: 'Test Member Two', date: DateTime(2026, 6, 5), amount: 300, mode: 'UPI', frequency: 'Weekly', status: 'pending', shgName: 'Sneha SHG'),
      ];
  @override
  Future<List<SavingsEntry>> fetchForMember(String? memberId) async => const [];
  @override
  Future<List<SavingsEntry>> fetchForShg(String? shgId) async => const [];
}

/// Round 146 replaced the old silently-empty zero-state for crp/clf/admin
/// (no `profile.shgId` of their own) with an honest "doesn't apply to your
/// role" message. Round 168 (Loans) established the real fix template —
/// surface the capability RLS already grants instead of explaining it
/// away — and this file now proves that template applied here too: a real
/// platform-wide portfolio, not the dead-end message.
void main() {
  Future<void> boot(WidgetTester tester, AppState appState, {SavingsRepository? repository}) async {
    SharedPreferences.setMockInitialValues(const {});
    await appState.init();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          home: SavingsHomePage(repository: repository),
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

  group('live mode — staff-with-no-linked-SHG platform-wide portfolio (round 168)', () {
    setUp(() {
      SupabaseService.isConfigured = true;
    });
    tearDown(() {
      SupabaseService.isConfigured = false;
    });

    for (final staffRole in ['crp', 'clf', 'admin']) {
      testWidgets('a $staffRole account with no linked SHG sees a real cross-SHG portfolio, not the old dead-end message', (tester) async {
        final profile = Profile(id: 'staff-$staffRole', name: 'QA $staffRole', role: staffRole, shgId: null);
        final appState = AppState(
          profileRepository: _FixedProfileRepository(profile),
          authService: _FakeAuthServiceWithSession(),
        );

        await boot(tester, appState, repository: _FakePlatformWideSavingsRepository());

        expect(find.text("Your role isn't linked to a specific SHG — this view doesn't apply"), findsNothing);
        expect(find.text('Platform Savings'), findsOneWidget);
        expect(find.text('Recent Entries (All SHGs)'), findsOneWidget);
        // Only entry-1 is verified (₹500) — appears in both the stat card
        // total and its own row, since it's the sole verified entry.
        expect(find.text('₹500'), findsWidgets);
        expect(find.text('01 Jun 2026 · Cash · Jyothi SHG'), findsOneWidget, reason: 'each row must show which SHG it belongs to');
        expect(find.text('05 Jun 2026 · UPI · Sneha SHG'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a leader account with a real linked SHG does not see the guard message or the platform-wide labels', (tester) async {
      const profile = Profile(id: 'leader-1', name: 'QA Leader', role: 'leader', shgId: 'shg-1');
      final appState = AppState(
        profileRepository: _FixedProfileRepository(profile),
        authService: _FakeAuthServiceWithSession(),
      );

      await boot(tester, appState, repository: _FakePlatformWideSavingsRepository());

      expect(find.text("Your role isn't linked to a specific SHG — this view doesn't apply"), findsNothing);
      expect(find.text('Platform Savings'), findsNothing, reason: 'a leader has her own shgId — she gets the group view, not the platform-wide one');
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
