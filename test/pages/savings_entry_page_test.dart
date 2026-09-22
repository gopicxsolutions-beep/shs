import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/models/paged_result.dart';
import 'package:shg_saathi/models/profile.dart';
import 'package:shg_saathi/models/shg.dart';
import 'package:shg_saathi/pages/savings/savings_entry_page.dart';
import 'package:shg_saathi/repositories/savings_repository.dart';
import 'package:shg_saathi/repositories/shg_repository.dart';
import 'package:shg_saathi/routes/paths.dart';
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

/// Canned catalog + per-SHG rosters; records every roster lookup so a test can
/// prove WHICH SHG's members were requested.
class _FakeShgRepository extends ShgRepository {
  _FakeShgRepository({this.failMembers = false});
  final bool failMembers;
  final List<String?> memberLookups = [];

  static const _rosters = <String, List<Member>>{
    'shg-1': [
      Member(id: 'm-1', name: 'Anitha', role: 'member'),
      Member(id: 'm-2', name: 'Bhavani', role: 'member'),
      Member(id: 'm-3', name: 'Closed Account', role: 'member', isActive: false),
    ],
    'shg-2': [Member(id: 'm-9', name: 'Deepa', role: 'member')],
    'shg-empty': [],
  };

  @override
  Future<PagedResult<ShgProfile>> fetchAllShgs({String? afterName, int pageSize = 100}) async => const PagedResult(
        items: [ShgProfile(id: 'shg-1', name: 'Amara SHG'), ShgProfile(id: 'shg-2', name: 'Deepthi SHG'), ShgProfile(id: 'shg-empty', name: 'Empty SHG')],
        hasMore: false,
      );

  @override
  Future<List<Member>> fetchMembers(String? shgId) async {
    memberLookups.add(shgId);
    if (failMembers) throw Exception('network down');
    return _rosters[shgId] ?? const [];
  }
}

class _RecordingSavingsRepository extends SavingsRepository {
  ({String? memberId, String? shgId, num amount})? saved;
  @override
  Future<bool> addEntry({required String? memberId, required String? shgId, required num amount, required String mode, required String frequency}) async {
    saved = (memberId: memberId, shgId: shgId, amount: amount);
    return true;
  }
}

/// Regression coverage for a real crash found and fixed this session:
/// `_formKey` (a `GlobalKey<FormState>`) was referenced by validate() but
/// never attached to an actual `Form`, so `_formKey.currentState` was
/// always null and tapping Submit with an empty/invalid amount threw a
/// null-check error instead of showing a validation message.
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  Widget harness() => ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: MaterialApp(home: const SavingsEntryPage(), localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], supportedLocales: AppLocalizations.supportedLocales, ),
      );

  testWidgets('tapping Submit with an empty amount shows a validation error instead of crashing', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Submit Entry'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Enter an amount'), findsOneWidget);
  });

  testWidgets('tapping Submit with a zero amount shows a validation error instead of crashing', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '0');
    await tester.tap(find.text('Submit Entry'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Amount must be greater than zero'), findsOneWidget);
  });

  testWidgets('an unreasonably large amount is rejected with a sanity-check message', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '5000000');
    await tester.tap(find.text('Submit Entry'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Amount seems unusually large — please check and re-enter'), findsOneWidget);
  });

  // A tester reported "No members found in your SHG yet" on the admin's Add
  // Savings page even though SHGs with members existed: crp/clf/admin have no
  // `profile.shgId`, and the page loaded the roster with it regardless. Staff
  // must pick an SHG first (the DB already allows staff to record an entry for
  // any SHG's active member — `savings_insert_self_leader_or_staff`).
  group('platform-wide staff (crp/clf/admin) pick an SHG, then a member', () {
    setUp(() {
      SupabaseService.isConfigured = true;
      SharedPreferences.setMockInitialValues({});
    });
    tearDown(() {
      SupabaseService.isConfigured = false;
    });

    Future<AppState> signedInAs(String role, {String? shgId}) async {
      final appState = AppState(profileRepository: _FixedProfileRepository(Profile(id: 'u-$role', name: 'QA $role', role: role, shgId: shgId)), authService: _FakeAuthServiceWithSession());
      await appState.init();
      return appState;
    }

    Future<void> pump(WidgetTester tester, AppState appState, _FakeShgRepository shgRepo, _RecordingSavingsRepository savingsRepo) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, _) => SavingsEntryPage(repository: savingsRepo, shgRepository: shgRepo)),
        GoRoute(path: Paths.savings, builder: (_, _) => const Scaffold(body: Text('SAVINGS HOME'))),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ));
      await tester.pumpAndSettle();
    }

    Finder shgDropdown() => find.byType(DropdownButtonFormField<String>).first;
    Finder memberDropdown() => find.byType(DropdownButtonFormField<String>).last;

    Future<void> pickShg(WidgetTester tester, String name) async {
      await tester.tap(shgDropdown());
      await tester.pumpAndSettle();
      await tester.tap(find.text(name).last);
      await tester.pumpAndSettle();
    }

    for (final staffRole in ['crp', 'clf', 'admin']) {
      testWidgets('a $staffRole account no longer sees "No members found in your SHG yet" — it gets an SHG picker', (tester) async {
        final shgRepo = _FakeShgRepository();
        await pump(tester, await signedInAs(staffRole), shgRepo, _RecordingSavingsRepository());

        expect(find.textContaining('No members found in your SHG yet'), findsNothing, reason: 'this was the reported bug');
        expect(find.text('Select an SHG'), findsOneWidget);
        expect(find.text('Select an SHG first.'), findsOneWidget, reason: 'the member card explains why it is empty instead of looking broken');
        expect(shgRepo.memberLookups, isEmpty, reason: 'no roster fetch (least of all fetchMembers(null)) until an SHG is picked');
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets("picking an SHG loads THAT SHG's active members only", (tester) async {
      final shgRepo = _FakeShgRepository();
      await pump(tester, await signedInAs('admin'), shgRepo, _RecordingSavingsRepository());

      await pickShg(tester, 'Amara SHG');
      expect(shgRepo.memberLookups, ['shg-1']);

      await tester.tap(memberDropdown());
      await tester.pumpAndSettle();
      expect(find.text('Anitha'), findsOneWidget);
      expect(find.text('Bhavani'), findsOneWidget);
      expect(find.text('Closed Account'), findsNothing, reason: 'a deactivated member must not be offered a new entry');
      expect(find.text('Deepa'), findsNothing, reason: "another SHG's member must not leak into this SHG's list");
      expect(tester.takeException(), isNull);
    });

    testWidgets('switching SHG replaces the roster and clears the previously-picked member', (tester) async {
      final shgRepo = _FakeShgRepository();
      await pump(tester, await signedInAs('admin'), shgRepo, _RecordingSavingsRepository());

      await pickShg(tester, 'Amara SHG');
      await tester.tap(memberDropdown());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anitha').last);
      await tester.pumpAndSettle();

      await pickShg(tester, 'Deepthi SHG');
      expect(shgRepo.memberLookups, ['shg-1', 'shg-2']);
      await tester.tap(memberDropdown());
      await tester.pumpAndSettle();
      expect(find.text('Deepa'), findsOneWidget);
      expect(find.text('Anitha'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an SHG that genuinely has no active members says so (and says "this SHG", not "your SHG")', (tester) async {
      await pump(tester, await signedInAs('crp'), _FakeShgRepository(), _RecordingSavingsRepository());

      await pickShg(tester, 'Empty SHG');
      expect(find.textContaining('This SHG has no active members yet'), findsOneWidget);
      expect(find.textContaining('No members found in your SHG yet'), findsNothing);
    });

    testWidgets('a failed roster fetch shows an error, NOT the misleading "no members" message', (tester) async {
      await pump(tester, await signedInAs('admin'), _FakeShgRepository(failMembers: true), _RecordingSavingsRepository());

      await pickShg(tester, 'Amara SHG');
      expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
      expect(find.textContaining('no active members'), findsNothing);
      expect(find.textContaining('No members found'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('submitting without an SHG is refused with a reason', (tester) async {
      final savingsRepo = _RecordingSavingsRepository();
      await pump(tester, await signedInAs('admin'), _FakeShgRepository(), savingsRepo);

      await tester.enterText(find.byType(TextFormField), '500');
      await tester.tap(find.text('Submit Entry'));
      await tester.pumpAndSettle();

      // Once as the member card's placeholder, once as the error line.
      expect(find.text('Select an SHG first.'), findsNWidgets(2));
      expect(savingsRepo.saved, isNull, reason: 'nothing may be written without a target SHG');
    });

    testWidgets('a full staff submission records the entry against the PICKED SHG and member, then returns to Savings', (tester) async {
      final savingsRepo = _RecordingSavingsRepository();
      await pump(tester, await signedInAs('admin'), _FakeShgRepository(), savingsRepo);

      await pickShg(tester, 'Amara SHG');
      await tester.tap(memberDropdown());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bhavani').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '750');
      await tester.tap(find.text('Submit Entry'));
      await tester.pumpAndSettle();

      expect(savingsRepo.saved, isNotNull);
      expect(savingsRepo.saved!.shgId, 'shg-1', reason: "addEntry used to be handed the admin's own null shgId");
      expect(savingsRepo.saved!.memberId, 'm-2');
      expect(savingsRepo.saved!.amount, 750);
      expect(find.text('SAVINGS HOME'), findsOneWidget);
    });

    testWidgets('a leader is unaffected: no SHG picker, roster comes from her own SHG', (tester) async {
      final shgRepo = _FakeShgRepository();
      final savingsRepo = _RecordingSavingsRepository();
      await pump(tester, await signedInAs('leader', shgId: 'shg-1'), shgRepo, savingsRepo);

      expect(find.text('Select an SHG'), findsNothing);
      expect(shgRepo.memberLookups, ['shg-1']);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget, reason: 'just the member picker');

      await tester.tap(memberDropdown());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anitha').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '100');
      await tester.tap(find.text('Submit Entry'));
      await tester.pumpAndSettle();

      expect(savingsRepo.saved?.shgId, 'shg-1');
      expect(savingsRepo.saved?.memberId, 'm-1');
    });
  });
}
