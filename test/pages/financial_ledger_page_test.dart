import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/models/financial_entry.dart';
import 'package:shg_saathi/models/paged_result.dart';
import 'package:shg_saathi/models/profile.dart';
import 'package:shg_saathi/pages/financial/financial_ledger_page.dart';
import 'package:shg_saathi/repositories/financial_repository.dart';
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
class _FakePlatformWideFinancialRepository extends FinancialRepository {
  @override
  Future<PagedResult<FinancialEntry>> fetchAllForStaff(String entryType, {DateTime? afterEntryDate, DateTime? afterCreatedAt, int pageSize = 100}) async => PagedResult(
        items: [
          FinancialEntry(id: 'e-1', entryType: entryType, description: 'Meeting collection', debit: 0, credit: 5000, balance: 15000, date: DateTime(2026, 6, 1), createdAt: DateTime(2026, 6, 1), shgName: 'Jyothi SHG'),
          FinancialEntry(id: 'e-2', entryType: entryType, description: 'Stationery purchase', debit: 500, credit: 0, balance: 800, date: DateTime(2026, 6, 3), createdAt: DateTime(2026, 6, 3), shgName: 'Sneha SHG'),
        ],
        hasMore: false,
      );
  @override
  Future<PagedResult<FinancialEntry>> fetchForShg(String? shgId, String entryType, {DateTime? afterEntryDate, DateTime? afterCreatedAt, int pageSize = 100}) async => const PagedResult(items: [], hasMore: false);
}

/// Round 168 (Loans/Savings/Livelihood) fix template applied to the
/// cashbook/ledger/bank/audit shared page: crp/clf/admin (no `shgId` of
/// their own) used to see round 147's honest "doesn't apply" message — now
/// a real platform-wide feed, since `financial_ledger_select_shg_or_staff`
/// already grants `is_staff()` unrestricted platform-wide read. Each row is
/// tagged with its SHG name — more load-bearing here than in the other
/// three modules, since `balance` is a per-SHG running total that would
/// otherwise appear to jump around arbitrarily in a flat cross-SHG list.
void main() {
  Future<void> boot(WidgetTester tester, AppState appState, {FinancialRepository? repository}) async {
    SharedPreferences.setMockInitialValues(const {});
    await appState.init();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          home: FinancialLedgerPage(entryType: 'cashbook', repository: repository),
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
      testWidgets('a $staffRole account with no linked SHG sees a real cross-SHG feed, not the old dead-end message, and no Add-entry button', (tester) async {
        final profile = Profile(id: 'staff-$staffRole', name: 'QA $staffRole', role: staffRole, shgId: null);
        final appState = AppState(
          profileRepository: _FixedProfileRepository(profile),
          authService: _FakeAuthServiceWithSession(),
        );

        await boot(tester, appState, repository: _FakePlatformWideFinancialRepository());

        expect(find.text("Your role isn't linked to a specific SHG — this view doesn't apply"), findsNothing);
        expect(find.text('Meeting collection'), findsOneWidget);
        expect(find.text('Stationery purchase'), findsOneWidget);
        expect(find.textContaining('SHG: Jyothi SHG'), findsOneWidget, reason: 'a flat cross-SHG feed needs the SHG tagged per row — balance is a per-SHG running total');
        expect(find.textContaining('SHG: Sneha SHG'), findsOneWidget);
        expect(find.byTooltip('Add entry'), findsNothing, reason: 'there is no SHG to post a platform-wide entry against');
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a leader account with a real linked SHG sees her own SHG-scoped ledger and a working Add-entry button, no SHG tags', (tester) async {
      const profile = Profile(id: 'leader-1', name: 'QA Leader', role: 'leader', shgId: 'shg-1');
      final appState = AppState(
        profileRepository: _FixedProfileRepository(profile),
        authService: _FakeAuthServiceWithSession(),
      );

      await boot(tester, appState, repository: _FakePlatformWideFinancialRepository());

      expect(find.text("Your role isn't linked to a specific SHG — this view doesn't apply"), findsNothing);
      expect(find.textContaining('SHG:'), findsNothing, reason: 'a leader only ever sees her own SHG, so the tag would be redundant noise');
      expect(find.byTooltip('Add entry'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
