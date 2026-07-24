import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/meetings/meeting_detail_page.dart';
import 'package:shg_saathi/pages/meetings/meetings_home_page.dart';
import 'package:shg_saathi/repositories/meeting_repository.dart';
import 'package:shg_saathi/services/notification_service.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/state/app_state.dart';
import 'package:shg_saathi/widgets/list_row.dart';

/// Records calls instead of touching a platform channel — see
/// `LocalNotificationService`'s doc comment.
class _FakeNotificationService implements NotificationService {
  final List<String> cancelledMeetings = [];

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> scheduleMeetingReminder({required String meetingId, required DateTime meetingAt, required String venue}) async {}

  @override
  Future<void> cancelMeetingReminder(String meetingId) async {
    cancelledMeetings.add(meetingId);
  }

  @override
  Future<void> scheduleLoanDueReminder({required String loanId, required DateTime dueDate, required num emiAmount}) async {}

  @override
  Future<void> cancelLoanDueReminder(String loanId) async {}

  @override
  Future<void> showAnnouncementNotification({required String announcementId, required String title}) async {}
}

/// Regression coverage for the "Cancel Meeting" action added to
/// `MeetingDetailPage` — before this, `MeetingRepository.setStatus()` was
/// fully wired end-to-end but had zero call sites anywhere under `lib/pages`,
/// so a scheduled meeting could never actually be cancelled and
/// `meetings_home_page.dart`'s red 'cancelled' badge styling could never be
/// reached.
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

  Future<void> pumpDetail(WidgetTester tester, AppState appState, String meetingId) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(home: MeetingDetailPage(meetingId: meetingId), localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], supportedLocales: AppLocalizations.supportedLocales, ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Schedules a brand-new, guaranteed-'upcoming' meeting (rather than
  /// reusing one of `lib/data/meetings.dart`'s fixed mock ids) so this test
  /// doesn't depend on — or pollute — any other test's view of the shared
  /// mock roster/meeting list.
  Future<String> scheduleTestMeeting(String venue) async {
    final repo = MeetingRepository();
    await repo.schedule(
      shgId: null,
      date: DateTime.now().add(const Duration(days: 3)),
      time: '5:00 PM',
      venue: venue,
      agenda: '__TEST__ agenda for $venue',
    );
    final list = await repo.fetchForShg('demo-shg');
    return list.firstWhere((m) => m.venue == venue).id;
  }

  testWidgets('a plain member never sees a Cancel Meeting action', (tester) async {
    final meetingId = await scheduleTestMeeting('__TEST__ Venue Member Gate');
    final appState = await bootedAppState(role: 'member');

    await pumpDetail(tester, appState, meetingId);

    expect(find.text('Cancel Meeting'), findsNothing);
    expect(find.text('upcoming'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a leader can cancel an upcoming meeting via the confirm dialog, and it then shows cancelled on both the detail page and the meetings list', (tester) async {
    const venue = '__TEST__ Venue Cancel Flow';
    final meetingId = await scheduleTestMeeting(venue);
    final appState = await bootedAppState(role: 'leader');
    // A fake notification service — matching every other test in this file
    // and `meetings_home_page_test.dart`'s own harness — for both pumps
    // below. Neither `MeetingDetailPage` nor `MeetingsHomePage` is ever
    // otherwise pumped against the real on-device `LocalNotificationService`
    // in this test suite; doing so here left this test hanging on a real
    // (never-mocked) platform channel call inside `MeetingsHomePage`'s own
    // `_loadAndSyncReminders`, unrelated to the "Cancel Meeting" behavior
    // this test actually exercises.
    final fake = _FakeNotificationService();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(home: MeetingDetailPage(meetingId: meetingId, notificationService: fake), localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], supportedLocales: AppLocalizations.supportedLocales, ),
      ),
    );
    await tester.pumpAndSettle();

    // The action is only offered while the meeting is still 'upcoming'.
    expect(find.text('Cancel Meeting'), findsOneWidget);
    expect(find.text('upcoming'), findsOneWidget);

    // Opening the dialog and choosing "Keep Meeting" must not cancel it.
    await tester.tap(find.text('Cancel Meeting'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel meeting?'), findsOneWidget);
    await tester.tap(find.text('Keep Meeting'));
    await tester.pumpAndSettle();
    expect(find.text('upcoming'), findsOneWidget);
    expect(find.text('Cancel Meeting'), findsOneWidget);

    // Now actually confirm the cancellation.
    await tester.tap(find.text('Cancel Meeting'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel meeting?'), findsOneWidget);
    // Two widgets now read "Cancel Meeting": the card that opened the dialog
    // (still present underneath) and the dialog's own confirm button — the
    // confirm button is a FilledButton, so disambiguate on that.
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel Meeting'));
    await tester.pumpAndSettle();

    expect(find.text('Demo mode — cancelled for the rest of this session (connect Supabase to persist)'), findsOneWidget);
    // The badge flips to 'cancelled' and the action itself disappears (an
    // already-cancelled meeting has nothing left to cancel).
    expect(find.text('cancelled'), findsOneWidget);
    expect(find.text('upcoming'), findsNothing);
    expect(find.text('Cancel Meeting'), findsNothing);
    expect(tester.takeException(), isNull);

    // The cancellation must also be visible from the meetings list — not
    // silently vanish, and not still show as upcoming there either.
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(home: MeetingsHomePage(notificationService: fake), localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], supportedLocales: AppLocalizations.supportedLocales, ),
      ),
    );
    await tester.pumpAndSettle();

    final agendaText = find.text('__TEST__ agenda for $venue');
    expect(agendaText, findsOneWidget);
    // The row it's in must carry the red 'cancelled' badge, not sit under
    // the "Upcoming" section (which is exactly what a leader would see if
    // this fix were missing — the meeting either vanishing entirely from
    // the demo-mode session-local list, or still rendering under Upcoming).
    // `AppListRow` (only ever used for the "Past Meetings" list) — not the
    // `_meetingCard` layout the "Upcoming" section renders — so finding this
    // agenda text inside one proves the cancelled meeting moved into Past
    // Meetings rather than lingering under Upcoming.
    final row = find.ancestor(of: agendaText, matching: find.byType(AppListRow));
    expect(row, findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('cancelled')), findsOneWidget);
  });

  testWidgets('a leader cannot cancel a meeting whose scheduled date has already passed, even though its status is still "upcoming" (nothing in the app ever advances it to "completed")', (tester) async {
    // Reproduces the exact gaming vector an adversarial review flagged:
    // nothing in the app ever transitions a meeting's status to
    // 'completed' (see `Meeting.hasPassed`'s doc comment), so a meeting
    // that genuinely happened months ago — with real recorded attendance —
    // still sits at status 'upcoming' forever unless explicitly cancelled.
    // Before this fix, the Cancel Meeting gate checked only
    // `isLeaderOrStaff && meeting.status == 'upcoming'`, so this exact
    // meeting would still offer "Cancel Meeting", letting a leader
    // retroactively purge it from every completed-meeting count /
    // avgAttendancePct / attendance trend / CRP health score that derives
    // from it.
    final repo = MeetingRepository();
    const venue = '__TEST__ Venue Past Meeting Gaming';
    await repo.schedule(
      shgId: null,
      date: DateTime.now().subtract(const Duration(days: 60)),
      time: '4:00 PM',
      venue: venue,
      agenda: '__TEST__ agenda for $venue',
    );
    final list = await repo.fetchForShg('demo-shg');
    final scheduled = list.firstWhere((m) => m.venue == venue);
    // Sanity check: this is exactly the shape the bug describes — a real
    // past meeting still reporting status 'upcoming'.
    expect(scheduled.status, 'upcoming');
    expect(scheduled.hasPassed, isTrue);

    final appState = await bootedAppState(role: 'leader');
    await pumpDetail(tester, appState, scheduled.id);

    // The badge still legitimately reads 'upcoming' (status genuinely never
    // advanced) — but the Cancel Meeting action must not be offered, since
    // the meeting has already happened.
    expect(find.text('upcoming'), findsOneWidget);
    expect(find.text('Cancel Meeting'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling a meeting also cancels this device\'s own scheduled reminder for it', (tester) async {
    const venue = '__TEST__ Venue Reminder Cancel';
    final meetingId = await scheduleTestMeeting(venue);
    final appState = await bootedAppState(role: 'leader');
    final fake = _FakeNotificationService();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(home: MeetingDetailPage(meetingId: meetingId, notificationService: fake), localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], supportedLocales: AppLocalizations.supportedLocales, ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel Meeting'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel Meeting'));
    await tester.pumpAndSettle();

    expect(find.text('cancelled'), findsOneWidget);
    expect(fake.cancelledMeetings, contains(meetingId));
    expect(tester.takeException(), isNull);
  });
}
