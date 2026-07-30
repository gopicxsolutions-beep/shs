import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/models/meeting.dart';
import 'package:shg_saathi/models/profile.dart';
import 'package:shg_saathi/pages/meetings/meeting_attendance_page.dart';
import 'package:shg_saathi/repositories/meeting_repository.dart';
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

/// Canned cross-SHG pending data — avoids a real network call in a test
/// environment with no live backend.
class _FakePlatformWideMeetingRepository extends MeetingRepository {
  @override
  Future<List<Meeting>> fetchAllForStaff() async => [
        Meeting(id: 'm-1', shgId: 'shg-1', date: DateTime.now().add(const Duration(days: 3)), venue: 'Community Hall', agenda: 'Monthly review', status: 'upcoming', shgName: 'Amara SHG'),
        Meeting(id: 'm-2', shgId: 'shg-2', date: DateTime.now().add(const Duration(days: 5)), venue: 'Panchayat Office', agenda: 'Loan discussion', status: 'upcoming', shgName: 'Deepthi SHG'),
      ];
  @override
  Future<List<AttendanceRow>> fetchAttendance(String meetingId, String? shgId) async => [
        AttendanceRow(memberId: 'mem-a', memberName: shgId == 'shg-1' ? 'Padma' : 'Saroja', present: false),
      ];
  @override
  Future<List<Meeting>> fetchForShg(String? shgId) async => const [];
}

/// A single SHG with both an already-occurred meeting and a genuinely
/// future one — regression coverage for gap-hunt iteration 36's live-mode
/// default-meeting-selection fix (a brand-new SHG whose only meeting was
/// still weeks out used to default the picker there, where RLS silently
/// rejects every attendance write since `meeting_date <= current_date` is
/// required — reproduced live against a real SHG).
class _FakeMixedPastFutureMeetingRepository extends MeetingRepository {
  @override
  Future<List<Meeting>> fetchForShg(String? shgId) async => [
        Meeting(id: 'past-1', shgId: 'shg-1', date: DateTime.now().subtract(const Duration(days: 10)), venue: 'Community Hall', agenda: 'Last month review', status: 'upcoming'),
        Meeting(id: 'future-1', shgId: 'shg-1', date: DateTime.now().add(const Duration(days: 14)), venue: 'Community Hall', agenda: 'Next review', status: 'upcoming'),
      ];
  @override
  Future<List<AttendanceRow>> fetchAttendance(String meetingId, String? shgId) async => [AttendanceRow(memberId: 'mem-a', memberName: 'Padma', present: false)];
}

/// A brand-new SHG whose ONLY meeting on record is still weeks out — the
/// exact shape of the live bug report this fix addresses.
class _FakeFutureOnlyMeetingRepository extends MeetingRepository {
  @override
  Future<List<Meeting>> fetchForShg(String? shgId) async => [
        Meeting(id: 'future-only-1', shgId: 'shg-1', date: DateTime.now().add(const Duration(days: 16)), venue: 'Community Hall', agenda: 'First meeting', status: 'upcoming'),
      ];
  @override
  Future<List<AttendanceRow>> fetchAttendance(String meetingId, String? shgId) async => [AttendanceRow(memberId: 'mem-a', memberName: 'Padma', present: false)];
}

/// Regression coverage for the second finding an adversarial review flagged
/// in the "Cancel Meeting" / attendance-marking interaction:
/// `MeetingAttendancePage`'s dropdown was built from the FULL, unfiltered
/// meetings list — the upcoming-and-not-passed check only ever picked the
/// *default* selection, never restricted which meetings were selectable at
/// all — so a leader could still pick an already-cancelled meeting from the
/// picker and flip its attendance switches for it after cancellation,
/// writing fresh `meeting_attendance` rows tied to a cancelled meeting.
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  Future<AppState> bootedAppState({required String role}) async {
    SharedPreferences.setMockInitialValues({
      'shg_session_started': true,
      'shg_authenticated': true,
      'shg_role': role,
    });
    final appState = AppState();
    await appState.init();
    return appState;
  }

  Future<void> pumpAttendancePage(WidgetTester tester, AppState appState) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(home: const MeetingAttendancePage(), localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], supportedLocales: AppLocalizations.supportedLocales, ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a cancelled meeting is excluded from the attendance picker entirely, not just from the default selection', (tester) async {
    final repo = MeetingRepository();
    const cancelledVenue = '__TEST__ Venue Attendance Cancelled Pick';
    const openVenue = '__TEST__ Venue Attendance Open Pick';
    final cancelledDate = DateTime.now().add(const Duration(days: 2));
    final openDate = DateTime.now().add(const Duration(days: 9));

    await repo.schedule(shgId: null, date: cancelledDate, time: '4:00 PM', venue: cancelledVenue, agenda: '__TEST__ agenda cancelled pick');
    // `MeetingRepository.schedule()`'s demo-mode id is derived from
    // `DateTime.now().microsecondsSinceEpoch` — a real (if narrow) delay is
    // needed here so this second, back-to-back schedule() call cannot land
    // on the exact same id as the first (observed to happen on this
    // platform's timer resolution without it), which would otherwise make
    // both meetings share one id and both get cancelled together below.
    // Must go through `tester.runAsync` (not a bare `await Future.delayed`):
    // `testWidgets` bodies run under `AutomatedTestWidgetsFlutterBinding`'s
    // fake clock, which only advances when `tester.pump(duration)` is
    // explicitly called — a bare real-timer `await Future.delayed(...)` here
    // (with no pump in between) registers a timer that fake-clock advancement
    // never reaches, so it never completes and the test hangs forever (only
    // surfacing, if at all, as a 10-minute per-test timeout). `runAsync` is
    // `flutter_test`'s sanctioned escape hatch: it runs the given callback
    // against the real, un-faked clock/event loop instead.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await repo.schedule(shgId: null, date: openDate, time: '4:00 PM', venue: openVenue, agenda: '__TEST__ agenda open pick');

    final list = await repo.fetchForShg('demo-shg');
    final cancelledId = list.firstWhere((m) => m.venue == cancelledVenue).id;
    final openId = list.firstWhere((m) => m.venue == openVenue).id;
    expect(cancelledId, isNot(equals(openId)), reason: 'sanity check: the two scheduled test meetings must have distinct ids');
    await repo.setStatus(cancelledId, 'cancelled');

    final appState = await bootedAppState(role: 'leader');
    await pumpAttendancePage(tester, appState);

    // Defaults to the still-genuinely-upcoming meeting, not the cancelled
    // one, even though the cancelled meeting's own date sorts sooner.
    expect(find.text(DateFormat('dd MMM yyyy').format(openDate)), findsOneWidget);
    expect(find.text(DateFormat('dd MMM yyyy').format(cancelledDate)), findsNothing);

    // Open the picker itself and confirm the cancelled meeting is not
    // offered as a choice at all — not merely skipped as the default. This
    // is the actual bug: before the fix, the dropdown's `items` list was
    // built from the unfiltered meetings list, so the cancelled meeting was
    // still selectable here even though it was correctly never the default.
    final cancelledLabel = DateFormat('dd MMM').format(cancelledDate);
    final openLabel = DateFormat('dd MMM').format(openDate);
    await tester.tap(find.byType(DropdownButton<Meeting>));
    await tester.pumpAndSettle();

    expect(find.text(cancelledLabel), findsNothing);
    expect(find.text(openLabel), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('MeetingRepository.markAttendance refuses to write attendance for an already-cancelled meeting', () async {
    final repo = MeetingRepository();
    const venue = '__TEST__ Venue Repo MarkAttendance Cancelled';
    await repo.schedule(shgId: null, date: DateTime.now().add(const Duration(days: 4)), time: '5:00 PM', venue: venue, agenda: '__TEST__ agenda repo mark cancelled');
    final list = await repo.fetchForShg('demo-shg');
    final meetingId = list.firstWhere((m) => m.venue == venue).id;

    // Sanity check: marking attendance works normally before cancellation.
    await repo.markAttendance(meetingId, 'm1', false);
    final beforeRoster = await repo.fetchAttendance(meetingId, 'demo-shg');
    expect(beforeRoster.firstWhere((r) => r.memberId == 'm1').present, isFalse);

    await repo.setStatus(meetingId, 'cancelled');

    await expectLater(
      repo.markAttendance(meetingId, 'm1', true),
      throwsA(isA<StateError>()),
    );

    // And the earlier (pre-cancellation) mark must not have been
    // overwritten by the rejected call either.
    final afterRoster = await repo.fetchAttendance(meetingId, 'demo-shg');
    expect(afterRoster.firstWhere((r) => r.memberId == 'm1').present, isFalse);
  });

  // Round 168's fix template (Loans, Savings, Livelihood, Financial Ledger,
  // Meetings home) applied to the attendance picker: crp/clf/admin (no
  // `shgId` of their own) used to see a `commonStaffNoShgMessage` dead end —
  // now a real platform-wide meeting picker, since `meetings_select_shg_or_
  // staff`/`meeting_attendance_self_or_leader` already grant `is_staff()`
  // unrestricted platform-wide read/write. Uses live mode + an injected fake
  // repository (not the demo-mode session-local state the tests above/below
  // mutate), so ordering relative to them doesn't matter — placed before the
  // "runs last" test below anyway, so that comment's placement stays honest.
  group('platform-wide staff picker (round 168)', () {
    setUp(() {
      SupabaseService.isConfigured = true;
    });
    tearDown(() {
      SupabaseService.isConfigured = false;
    });

    Future<void> pumpWithRepo(WidgetTester tester, AppState appState, MeetingRepository repository) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: MeetingAttendancePage(repository: repository),
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

        await pumpWithRepo(tester, appState, _FakePlatformWideMeetingRepository());

        expect(find.text("Your role isn't linked to a specific SHG — this view doesn't apply"), findsNothing);
        expect(find.textContaining('SHG: Amara SHG'), findsOneWidget, reason: 'the selected meeting card must show which SHG it belongs to');
        expect(find.text('Padma'), findsOneWidget, reason: 'the roster must be resolved from the SELECTED MEETING\'s own shgId (shg-1), not the viewer\'s (null)');
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a leader account with a real linked SHG sees her own SHG-scoped picker, no SHG tag', (tester) async {
      SharedPreferences.setMockInitialValues({});
      const profile = Profile(id: 'leader-1', name: 'QA Leader', role: 'leader', shgId: 'shg-1');
      final appState = AppState(profileRepository: _FixedProfileRepository(profile), authService: _FakeAuthServiceWithSession());
      await appState.init();

      await pumpWithRepo(tester, appState, _FakePlatformWideMeetingRepository());

      expect(find.text("Your role isn't linked to a specific SHG — this view doesn't apply"), findsNothing);
      expect(find.textContaining('SHG:'), findsNothing, reason: 'a leader only ever sees her own SHG, so the tag would be redundant noise');
      expect(tester.takeException(), isNull);
    });
  });

  // Gap-hunt iteration 36: live mode must default to (and only allow marking
  // attendance for) a meeting attendance can actually be written for —
  // never a genuinely future one, since `meeting_attendance_insert_self_or_
  // leader`/`meeting_attendance_update_self_or_leader` (RLS) require
  // `meeting_date <= current_date`. Reproduced live against a real SHG whose
  // only scheduled meeting was still weeks out: every attendance toggle
  // silently failed with a generic error.
  group('live-mode default selection avoids unmarkable future meetings (iteration 36)', () {
    setUp(() {
      SupabaseService.isConfigured = true;
    });
    tearDown(() {
      SupabaseService.isConfigured = false;
    });

    Future<void> pumpWithRepo(WidgetTester tester, AppState appState, MeetingRepository repository) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: MeetingAttendancePage(repository: repository),
            localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('defaults to the already-occurred meeting, not the further-out future one', (tester) async {
      SharedPreferences.setMockInitialValues({});
      const profile = Profile(id: 'leader-1', name: 'QA Leader', role: 'leader', shgId: 'shg-1');
      final appState = AppState(profileRepository: _FixedProfileRepository(profile), authService: _FakeAuthServiceWithSession());
      await appState.init();

      final pastDate = DateTime.now().subtract(const Duration(days: 10));
      final futureDate = DateTime.now().add(const Duration(days: 14));
      await pumpWithRepo(tester, appState, _FakeMixedPastFutureMeetingRepository());

      expect(find.text(DateFormat('dd MMM yyyy').format(pastDate)), findsOneWidget, reason: 'the already-occurred meeting is the one an admin/leader actually opens this page to act on');
      expect(find.text(DateFormat('dd MMM yyyy').format(futureDate)), findsNothing);
      // The switch on the (markable, past) selected meeting must remain
      // interactive — this fix must not disable attendance-marking for
      // meetings it IS legal to mark.
      final switchWidget = tester.widget<Switch>(find.byType(Switch).first);
      expect(switchWidget.onChanged, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a brand-new SHG with only a future meeting shows a notice and disables the switch instead of allowing a futile write', (tester) async {
      SharedPreferences.setMockInitialValues({});
      const profile = Profile(id: 'leader-2', name: 'QA Leader New', role: 'leader', shgId: 'shg-1');
      final appState = AppState(profileRepository: _FixedProfileRepository(profile), authService: _FakeAuthServiceWithSession());
      await appState.init();

      await pumpWithRepo(tester, appState, _FakeFutureOnlyMeetingRepository());

      final switchWidget = tester.widget<Switch>(find.byType(Switch).first);
      expect(switchWidget.onChanged, isNull, reason: 'toggling would always fail against RLS (meeting_date > current_date) — must be disabled, not left to fail silently');
      expect(find.textContaining("hasn't happened yet"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // Runs last: cancels every meeting this SHG has (the fixed mock meetings
  // included) to reach the genuinely-empty-picker state, which permanently
  // affects this file's shared session-local mock state — placed after
  // every other test so it can't affect their assumptions.
  testWidgets('if only cancelled meetings exist, the attendance page falls back to its empty state instead of offering one', (tester) async {
    final repo = MeetingRepository();
    const venue = '__TEST__ Venue Attendance Only Cancelled';
    await repo.schedule(shgId: null, date: DateTime.now().add(const Duration(days: 5)), time: '4:00 PM', venue: venue, agenda: '__TEST__ agenda only cancelled');
    final list = await repo.fetchForShg('demo-shg');

    for (final m in list) {
      await repo.setStatus(m.id, 'cancelled');
    }

    final appState = await bootedAppState(role: 'leader');
    await pumpAttendancePage(tester, appState);

    expect(find.text('No meetings to mark attendance for'), findsOneWidget);
    expect(find.byType(DropdownButton<Meeting>), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
