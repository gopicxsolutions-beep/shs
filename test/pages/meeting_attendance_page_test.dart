import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/models/meeting.dart';
import 'package:shg_saathi/pages/meetings/meeting_attendance_page.dart';
import 'package:shg_saathi/repositories/meeting_repository.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/state/app_state.dart';

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
