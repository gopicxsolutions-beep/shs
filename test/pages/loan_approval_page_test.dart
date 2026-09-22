import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/models/loan.dart';
import 'package:shg_saathi/models/profile.dart';
import 'package:shg_saathi/pages/loans/loan_approval_page.dart';
import 'package:shg_saathi/repositories/loan_repository.dart';
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

/// Canned cross-SHG pending applications — avoids a real network call in a
/// test environment with no live backend, mirroring
/// `loans_home_page_test.dart`'s `_FakePlatformWideLoanRepository`.
class _FakePlatformWidePendingRepository extends LoanRepository {
  @override
  Future<List<Loan>> fetchAllForStaff() async => const [
        Loan(id: 'pending-1', memberId: 'mem-a', memberName: 'Padma', purpose: 'Sewing machine', amount: 8000, outstanding: 8000, emi: 0, tenureMonths: 10, status: 'pending', shgName: 'Amara SHG'),
        Loan(id: 'pending-2', memberId: 'mem-b', memberName: 'Saroja', purpose: 'Cattle feed', amount: 4000, outstanding: 4000, emi: 0, tenureMonths: 6, status: 'pending', shgName: 'Deepthi SHG'),
      ];
  @override
  Future<List<Loan>> fetchForShg(String? shgId) async => const [];
}

/// Regression coverage for round 146's fix on the second guard shape used
/// across that round's nine pages: `LoanApprovalPage` is already router-
/// restricted to leader/staff (`_roleRestrictedPrefixes` in router.dart),
/// so its own guard doesn't need an `isLeaderOrStaff` check — just
/// `isConfigured && shgId == null`. Round 168 replaced that guard's dead-end
/// message with a real platform-wide pending-approval queue (see
/// `LoanRepository.fetchAllForStaff()`); this file now proves that queue
/// actually renders cross-SHG data, not just that the old message is gone.
void main() {
  Future<void> boot(WidgetTester tester, AppState appState, {LoanRepository? repository}) async {
    SharedPreferences.setMockInitialValues(const {});
    await appState.init();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          home: LoanApprovalPage(repository: repository),
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

        await boot(tester, appState, repository: _FakePlatformWidePendingRepository());

        expect(find.text("Your role isn't linked to a specific SHG — this view doesn't apply"), findsNothing);
        expect(find.text('Padma'), findsOneWidget);
        expect(find.text('Saroja'), findsOneWidget);
        expect(find.text('SHG: Amara SHG'), findsOneWidget, reason: 'a flat cross-SHG queue needs the SHG tagged per card to disambiguate applicants');
        expect(find.text('SHG: Deepthi SHG'), findsOneWidget);
        expect(find.text('Approve'), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a leader account with a real linked SHG sees her own SHG-scoped queue, not the platform-wide one (no SHG tag shown)', (tester) async {
      const profile = Profile(id: 'leader-1', name: 'QA Leader', role: 'leader', shgId: 'shg-1');
      final appState = AppState(
        profileRepository: _FixedProfileRepository(profile),
        authService: _FakeAuthServiceWithSession(),
      );

      await boot(tester, appState, repository: _FakePlatformWidePendingRepository());

      expect(find.text("Your role isn't linked to a specific SHG — this view doesn't apply"), findsNothing);
      expect(find.textContaining('SHG:'), findsNothing, reason: 'a leader only ever sees her own SHG, so the per-card SHG tag would be redundant noise, not shown');
      expect(tester.takeException(), isNull);
    });
  });
}
