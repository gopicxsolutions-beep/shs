import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/models/profile.dart';
import 'package:shg_saathi/models/savings.dart';
import 'package:shg_saathi/pages/savings/savings_ledger_page.dart';
import 'package:shg_saathi/repositories/savings_repository.dart';
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

/// Canned cross-SHG pending entries — avoids a real network call in a test
/// environment with no live backend.
class _FakePlatformWidePendingSavingsRepository extends SavingsRepository {
  @override
  Future<List<SavingsEntry>> fetchAllForStaff() async => [
        SavingsEntry(id: 'entry-1', memberId: 'mem-a', memberName: 'Padma', date: DateTime(2026, 6, 1), amount: 400, mode: 'Cash', frequency: 'Monthly', status: 'pending', shgName: 'Amara SHG'),
        SavingsEntry(id: 'entry-2', memberId: 'mem-b', memberName: 'Saroja', date: DateTime(2026, 6, 3), amount: 250, mode: 'UPI', frequency: 'Weekly', status: 'pending', shgName: 'Deepthi SHG'),
      ];
  @override
  Future<List<SavingsEntry>> fetchForShg(String? shgId) async => const [];
  // A leader with a real `shgId` hits the realtime `StreamBuilder` branch,
  // not the one-shot fetch above — without this override, that branch's
  // default `watchForShg` would try a real Supabase Realtime channel
  // against a test environment with no live backend configured.
  @override
  Stream<List<SavingsEntry>> watchForShg(String shgId) => Stream.value(const []);
}

/// Round 168 (Loans) fix template applied to Savings: crp/clf/admin (no
/// `shgId` of their own) used to see round 146's honest "doesn't apply"
/// message on this ledger — now a real platform-wide pending-verification
/// queue, since `savings_select_shg_or_staff`/`savings_update_leader_or_
/// staff` already grant `is_staff()` unrestricted platform-wide access.
void main() {
  Future<void> boot(WidgetTester tester, AppState appState, {SavingsRepository? repository}) async {
    SharedPreferences.setMockInitialValues(const {});
    await appState.init();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          home: SavingsLedgerPage(repository: repository),
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

  group('live mode — staff-with-no-linked-SHG platform-wide queue (round 168)', () {
    setUp(() {
      SupabaseService.isConfigured = true;
    });
    tearDown(() {
      SupabaseService.isConfigured = false;
    });

    for (final staffRole in ['crp', 'clf', 'admin']) {
      testWidgets('a $staffRole account with no linked SHG sees a real cross-SHG pending queue, not the old dead-end message', (tester) async {
        final profile = Profile(id: 'staff-$staffRole', name: 'QA $staffRole', role: staffRole, shgId: null);
        final appState = AppState(
          profileRepository: _FixedProfileRepository(profile),
          authService: _FakeAuthServiceWithSession(),
        );

        await boot(tester, appState, repository: _FakePlatformWidePendingSavingsRepository());

        expect(find.text("Your role isn't linked to a specific SHG — this view doesn't apply"), findsNothing);
        expect(find.text('Padma'), findsOneWidget);
        expect(find.text('Saroja'), findsOneWidget);
        expect(find.textContaining('SHG: Amara SHG'), findsOneWidget, reason: 'a flat cross-SHG queue needs the SHG tagged per row to disambiguate members');
        expect(find.textContaining('SHG: Deepthi SHG'), findsOneWidget);
        expect(find.textContaining('· Verify'), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a leader account with a real linked SHG sees her own SHG-scoped ledger, not the platform-wide one (no SHG tag shown)', (tester) async {
      const profile = Profile(id: 'leader-1', name: 'QA Leader', role: 'leader', shgId: 'shg-1');
      final appState = AppState(
        profileRepository: _FixedProfileRepository(profile),
        authService: _FakeAuthServiceWithSession(),
      );

      await boot(tester, appState, repository: _FakePlatformWidePendingSavingsRepository());

      expect(find.text("Your role isn't linked to a specific SHG — this view doesn't apply"), findsNothing);
      expect(find.textContaining('SHG:'), findsNothing, reason: 'a leader only ever sees her own SHG, so the per-row SHG tag would be redundant noise');
      expect(tester.takeException(), isNull);
    });
  });
}
