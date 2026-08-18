import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/models/meeting.dart';
import 'package:shg_saathi/models/paged_result.dart';
import 'package:shg_saathi/models/profile.dart';
import 'package:shg_saathi/models/shg.dart';
import 'package:shg_saathi/pages/meetings/meeting_schedule_page.dart';
import 'package:shg_saathi/repositories/meeting_repository.dart';
import 'package:shg_saathi/repositories/shg_repository.dart';
import 'package:shg_saathi/services/auth_service.dart';
import 'package:shg_saathi/services/profile_repository.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/state/app_state.dart';
import 'package:shg_saathi/widgets/app_button.dart';

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

/// Canned SHG catalog — avoids a real network call in a test environment
/// with no live backend.
class _FakeShgCatalogRepository extends ShgRepository {
  @override
  Future<PagedResult<ShgProfile>> fetchAllShgs({String? afterName, int pageSize = 100}) async => const PagedResult(
        items: [ShgProfile(id: 'shg-1', name: 'Amara SHG'), ShgProfile(id: 'shg-2', name: 'Deepthi SHG')],
        hasMore: false,
      );
}

/// Records what `schedule()` was actually called with, without touching a
/// real backend.
class _RecordingMeetingRepository extends MeetingRepository {
  String? lastShgId;
  @override
  Future<List<Meeting>> fetchForShg(String? shgId) async => const [];
  @override
  Future<bool> schedule({required String? shgId, required DateTime date, required String time, required String venue, required String agenda}) async {
    lastShgId = shgId;
    return true;
  }
}

/// Regression coverage for a maxLength gap this session's earlier sweep
/// missed (that pass grepped a hardcoded list of controller variable
/// names that didn't include this page's `_venue`/`_agenda`) — both fields
/// had no character limit at all until now.
void main() {
  Widget harness() => ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: MaterialApp(home: const MeetingSchedulePage(), localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], supportedLocales: AppLocalizations.supportedLocales, ),
      );

  testWidgets('Venue and Agenda fields enforce their maxLength', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    final venueField = tester.widget<TextField>(find.widgetWithText(TextField, 'e.g. Anganwadi Centre, Kondapur', skipOffstage: false));
    expect(venueField.maxLength, 150);

    final agendaField = tester.widget<TextField>(find.widgetWithText(TextField, 'e.g. Monthly savings review & loan applications', skipOffstage: false));
    expect(agendaField.maxLength, 300);

    expect(tester.takeException(), isNull);
  });

  // A real, live-observed dead end: a platform-wide staff account (crp/clf/
  // admin, whose `profile.shgId` is always null by design) used to be
  // hard-blocked from this page entirely — but `MeetingAttendancePage`
  // already grants staff full platform-wide attendance-marking rights, and
  // an SHG with no leader account yet on record (a real state, not a test
  // fixture) could otherwise never get a meeting scheduled by ANYONE,
  // permanently blocking attendance for it. Staff must instead see a real
  // cross-SHG picker, mirroring `MeetingAttendancePage`'s round-168 fix.
  group('platform-wide staff SHG picker', () {
    setUp(() {
      SupabaseService.isConfigured = true;
    });
    tearDown(() {
      SupabaseService.isConfigured = false;
    });

    Future<void> pumpWithRepos(WidgetTester tester, AppState appState, MeetingRepository meetingRepo, ShgRepository shgRepo) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: MeetingSchedulePage(repository: meetingRepo, shgRepository: shgRepo),
            localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final staffRole in ['crp', 'clf', 'admin']) {
      testWidgets('a $staffRole account with no linked SHG sees a real cross-SHG picker, not the old dead-end message', (tester) async {
        SharedPreferences.setMockInitialValues({});
        final profile = Profile(id: 'staff-$staffRole', name: 'QA $staffRole', role: staffRole, shgId: null);
        final appState = AppState(profileRepository: _FixedProfileRepository(profile), authService: _FakeAuthServiceWithSession());
        await appState.init();

        await pumpWithRepos(tester, appState, _RecordingMeetingRepository(), _FakeShgCatalogRepository());

        expect(find.text("Your role isn't linked to a specific SHG — this view doesn't apply"), findsNothing);
        expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);

        // The dropdown only renders its currently-selected value (here: the
        // hint, since nothing is picked yet) until opened — confirm the real
        // SHG catalog is actually wired in by opening it.
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        expect(find.text('Amara SHG'), findsOneWidget);
        expect(find.text('Deepthi SHG'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('submitting without picking an SHG shows a validation error instead of silently failing', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final profile = Profile(id: 'staff-crp', name: 'QA crp', role: 'crp', shgId: null);
      final appState = AppState(profileRepository: _FixedProfileRepository(profile), authService: _FakeAuthServiceWithSession());
      await appState.init();
      final meetingRepo = _RecordingMeetingRepository();

      await pumpWithRepos(tester, appState, meetingRepo, _FakeShgCatalogRepository());
      await tester.enterText(find.widgetWithText(TextField, 'e.g. Anganwadi Centre, Kondapur', skipOffstage: false), 'Community Hall');
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      expect(find.text('Select an SHG to schedule this meeting for.'), findsOneWidget);
      expect(meetingRepo.lastShgId, isNull, reason: 'schedule() must never be called with no SHG selected');
      expect(tester.takeException(), isNull);
    });

    testWidgets('picking an SHG and submitting schedules the meeting for THAT SHG, not the staff account\'s own (null) one', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final profile = Profile(id: 'staff-crp', name: 'QA crp', role: 'crp', shgId: null);
      final appState = AppState(profileRepository: _FixedProfileRepository(profile), authService: _FakeAuthServiceWithSession());
      await appState.init();
      final meetingRepo = _RecordingMeetingRepository();

      await pumpWithRepos(tester, appState, meetingRepo, _FakeShgCatalogRepository());
      await tester.enterText(find.widgetWithText(TextField, 'e.g. Anganwadi Centre, Kondapur', skipOffstage: false), 'Community Hall');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deepthi SHG').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      expect(meetingRepo.lastShgId, 'shg-2');
      expect(tester.takeException(), isNull);
    });
  });
}
