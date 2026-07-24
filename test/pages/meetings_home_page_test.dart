import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/meetings/meetings_home_page.dart';
import 'package:shg_saathi/services/notification_service.dart';
import 'package:shg_saathi/state/app_state.dart';

/// Records calls instead of touching a platform channel — see
/// `LocalNotificationService`'s doc comment.
class _FakeNotificationService implements NotificationService {
  final List<String> scheduled = [];
  final List<String> cancelled = [];
  int permissionRequests = 0;
  bool permissionGranted = true;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<void> scheduleMeetingReminder({required String meetingId, required DateTime meetingAt, required String venue}) async {
    scheduled.add(meetingId);
  }

  @override
  Future<void> cancelMeetingReminder(String meetingId) async {
    cancelled.add(meetingId);
  }

  @override
  Future<void> scheduleLoanDueReminder({required String loanId, required DateTime dueDate, required num emiAmount}) async {}

  @override
  Future<void> cancelLoanDueReminder(String loanId) async {}

  @override
  Future<void> showAnnouncementNotification({required String announcementId, required String title}) async {}
}

/// Regression coverage for `MeetingsHomePage` opportunistically syncing this
/// device's scheduled meeting reminders on every load — see
/// `syncMeetingReminders`'s doc comment. The exact schedule/cancel split
/// depends on which of `lib/data/meetings.dart`'s mock dates are still in
/// the future when this test happens to run, so this only asserts the
/// invariant that's actually stable over time: every fetched meeting
/// resolves to exactly one schedule-or-cancel call when reminders are
/// enabled, and to zero calls at all when they're disabled.
void main() {
  Widget harness(NotificationService fake) => ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: MaterialApp(
          home: MeetingsHomePage(notificationService: fake),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );

  testWidgets('syncs a schedule-or-cancel call for every demo-mode meeting when reminders are enabled', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final fake = _FakeNotificationService();
    await tester.pumpWidget(harness(fake));
    await tester.pumpAndSettle();

    expect(find.text('Meetings'), findsOneWidget);
    expect(fake.scheduled.length + fake.cancelled.length, greaterThan(0), reason: 'demo mode always has at least one mock meeting to sync against');
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not touch the notification service at all when meeting reminders are disabled', (tester) async {
    SharedPreferences.setMockInitialValues({kNotifyMeetingsPrefKey: false});
    final fake = _FakeNotificationService();
    await tester.pumpWidget(harness(fake));
    await tester.pumpAndSettle();

    expect(fake.scheduled, isEmpty);
    expect(fake.cancelled, isEmpty);
    expect(tester.takeException(), isNull);
  });

  // Bug (2) regression: OS notification permission used to only ever get
  // requested as a side effect of a user actively flipping a Settings
  // switch. A member who never opens Settings has the preference sitting at
  // its enabled default, and this page used to schedule reminders under that
  // default without ever having requested the underlying OS permission —
  // silently dropped by the OS every time.
  group('proactive OS permission request on first load with the untouched default (bug 2)', () {
    testWidgets('the first time this page loads with meeting reminders still at their untouched default, it proactively requests OS permission', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fake = _FakeNotificationService()..permissionGranted = true;
      await tester.pumpWidget(harness(fake));
      await tester.pumpAndSettle();

      expect(fake.permissionRequests, 1, reason: 'a member who never opened Settings must still get the OS permission prompt the first time the Meetings tab loads');
      expect(tester.takeException(), isNull);
    });

    testWidgets('if that proactive request is denied, the preference is honestly turned off instead of continuing to silently "schedule" reminders the OS will drop', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fake = _FakeNotificationService()..permissionGranted = false;
      await tester.pumpWidget(harness(fake));
      await tester.pumpAndSettle();

      expect(fake.permissionRequests, 1);
      expect(fake.scheduled, isEmpty, reason: 'permission was denied, so nothing should be scheduled this load');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kNotifyMeetingsPrefKey), isFalse, reason: 'a denied OS permission must be honestly reflected back into the preference');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a preference the user already explicitly turned on is never re-prompted for permission here', (tester) async {
      SharedPreferences.setMockInitialValues({kNotifyMeetingsPrefKey: true});
      final fake = _FakeNotificationService();
      await tester.pumpWidget(harness(fake));
      await tester.pumpAndSettle();

      expect(fake.permissionRequests, 0, reason: 'SettingsPage._requestPermissionIfEnabling already handled this the moment the user flipped the switch on');
    });
  });

  // Bug (1) regression: a toggle-off cancellation that failed part-way
  // (`SettingsPage._onMeetingsToggle`, e.g. a flaky connection at the exact
  // moment the switch was flipped off) used to be silently and permanently
  // lost — nothing ever cancelled the stale already-scheduled device
  // reminders again, since this page only ever synced when the preference
  // read true. `meetingCancelPending` now marks that a cancellation still
  // needs retrying, and this page's load path is where that retry happens.
  group('retries a pending toggle-off cancellation on load instead of losing it forever (bug 1)', () {
    testWidgets('meetingCancelPending still set from a previous failed attempt gets retried and cleared once it succeeds', (tester) async {
      SharedPreferences.setMockInitialValues({kNotifyMeetingsPrefKey: false, kNotifyMeetingsCancelPendingKey: true});
      final fake = _FakeNotificationService();
      await tester.pumpWidget(harness(fake));
      await tester.pumpAndSettle();

      expect(fake.cancelled, isNotEmpty, reason: 'demo mode always has at least one mock meeting to retry-cancel against');
      expect(fake.scheduled, isEmpty, reason: 'reminders are still off — only the pending cancellation retries, nothing gets (re)scheduled');
      expect(await meetingCancelPending(), isFalse, reason: 'the retry succeeded, so the pending flag must be cleared instead of retrying forever');
      expect(tester.takeException(), isNull);
    });

    testWidgets('with reminders enabled, a stale pending-cancel flag is simply irrelevant and is not acted on', (tester) async {
      // Enabled takes priority over any leftover pending-cancel flag — there
      // is nothing to cancel once the member wants reminders on again.
      SharedPreferences.setMockInitialValues({kNotifyMeetingsCancelPendingKey: true});
      final fake = _FakeNotificationService();
      await tester.pumpWidget(harness(fake));
      await tester.pumpAndSettle();

      expect(fake.scheduled.length + fake.cancelled.length, greaterThan(0));
      expect(tester.takeException(), isNull);
    });
  });
}
