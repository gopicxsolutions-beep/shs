import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/announcements/announcements_home_page.dart';
import 'package:shg_saathi/services/notification_service.dart';
import 'package:shg_saathi/state/app_state.dart';

/// Records calls instead of touching a platform channel — see
/// `LocalNotificationService`'s doc comment.
class _FakeNotificationService implements NotificationService {
  final List<String> shown = [];
  int permissionRequests = 0;
  bool permissionGranted = true;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<void> scheduleMeetingReminder({required String meetingId, required DateTime meetingAt, required String venue}) async {}

  @override
  Future<void> cancelMeetingReminder(String meetingId) async {}

  @override
  Future<void> scheduleLoanDueReminder({required String loanId, required DateTime dueDate, required num emiAmount}) async {}

  @override
  Future<void> cancelLoanDueReminder(String loanId) async {}

  @override
  Future<void> showAnnouncementNotification({required String announcementId, required String title}) async {
    shown.add(announcementId);
  }
}

/// Regression coverage for `AnnouncementsHomePage` opportunistically firing a
/// local notification for any announcement newly seen on this device — see
/// `notifyNewAnnouncements`'s doc comment.
void main() {
  Widget harness(NotificationService fake) => ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: MaterialApp(
          home: AnnouncementsHomePage(notificationService: fake),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );

  testWidgets('the very first load on a device seeds the "seen" registry without notifying for the existing catalog', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final fake = _FakeNotificationService();
    await tester.pumpWidget(harness(fake));
    await tester.pumpAndSettle();

    expect(find.text('Announcements'), findsOneWidget);
    expect(fake.shown, isEmpty, reason: 'a member opening this tab for the first time after this feature ships should not get a backlog of notifications');
    expect(tester.takeException(), isNull);
  });

  testWidgets('once the registry already exists, an announcement not in it does notify', (tester) async {
    // A non-null but empty "seen" list means "this device has already been
    // through its first-run seeding pass" (see notifyNewAnnouncements's doc
    // comment) — so every announcement in the demo-mode catalog now counts
    // as newly-seen.
    SharedPreferences.setMockInitialValues({kSeenAnnouncementIdsPrefKey: <String>[]});
    final fake = _FakeNotificationService();
    await tester.pumpWidget(harness(fake));
    await tester.pumpAndSettle();

    expect(fake.shown, isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not touch the notification service at all when announcement notifications are disabled', (tester) async {
    SharedPreferences.setMockInitialValues({kSeenAnnouncementIdsPrefKey: <String>[], kNotifyAnnouncementsPrefKey: false});
    final fake = _FakeNotificationService();
    await tester.pumpWidget(harness(fake));
    await tester.pumpAndSettle();

    expect(fake.shown, isEmpty);
    expect(tester.takeException(), isNull);
  });

  // Bug (2) regression: see the matching group in meetings_home_page_test.dart
  // for the full write-up — the same shared `ensureNotificationPermissionForDefaultEnabled`
  // helper backs this page's load path too.
  group('proactive OS permission request on first load with the untouched default (bug 2)', () {
    testWidgets('the first time this page loads with announcement notifications still at their untouched default, it proactively requests OS permission', (tester) async {
      SharedPreferences.setMockInitialValues({kSeenAnnouncementIdsPrefKey: <String>[]});
      final fake = _FakeNotificationService()..permissionGranted = true;
      await tester.pumpWidget(harness(fake));
      await tester.pumpAndSettle();

      expect(fake.permissionRequests, 1, reason: 'a member who never opened Settings must still get the OS permission prompt the first time the Announcements tab loads');
      expect(tester.takeException(), isNull);
    });

    testWidgets('if that proactive request is denied, the preference is honestly turned off instead of continuing to silently notify', (tester) async {
      SharedPreferences.setMockInitialValues({kSeenAnnouncementIdsPrefKey: <String>[]});
      final fake = _FakeNotificationService()..permissionGranted = false;
      await tester.pumpWidget(harness(fake));
      await tester.pumpAndSettle();

      expect(fake.permissionRequests, 1);
      expect(fake.shown, isEmpty, reason: 'permission was denied, so nothing should be notified this load');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kNotifyAnnouncementsPrefKey), isFalse, reason: 'a denied OS permission must be honestly reflected back into the preference');
      expect(tester.takeException(), isNull);
    });
  });
}
