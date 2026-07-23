import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/loans/loans_home_page.dart';
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
  Future<void> scheduleMeetingReminder({required String meetingId, required DateTime meetingAt, required String venue}) async {}

  @override
  Future<void> cancelMeetingReminder(String meetingId) async {}

  @override
  Future<void> scheduleLoanDueReminder({required String loanId, required DateTime dueDate, required num emiAmount}) async {
    scheduled.add(loanId);
  }

  @override
  Future<void> cancelLoanDueReminder(String loanId) async {
    cancelled.add(loanId);
  }

  @override
  Future<void> showAnnouncementNotification({required String announcementId, required String title}) async {}
}

/// Regression coverage for `LoansHomePage` opportunistically syncing this
/// member's own loan EMI due-date reminders on every load — see
/// `syncLoanDueReminders`'s doc comment. As with the equivalent meetings
/// coverage, this asserts the stable invariant (every one of this member's
/// own demo-mode loans resolves to exactly one schedule-or-cancel call when
/// enabled, zero calls at all when disabled) rather than hardcoding which
/// specific mock loans happen to be active/overdue right now.
void main() {
  Widget harness(NotificationService fake) => ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: MaterialApp(home: LoansHomePage(notificationService: fake), localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], supportedLocales: AppLocalizations.supportedLocales, ),
      );

  testWidgets('syncs a schedule-or-cancel call for every demo-mode loan when payment alerts are enabled', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final fake = _FakeNotificationService();
    await tester.pumpWidget(harness(fake));
    await tester.pumpAndSettle();

    expect(find.text('Loans'), findsOneWidget);
    // The default demo persona ("Lakshmi Devi") has at least one active loan
    // in lib/data/loans.dart.
    expect(fake.scheduled.length + fake.cancelled.length, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not touch the notification service at all when payment alerts are disabled', (tester) async {
    SharedPreferences.setMockInitialValues({kNotifyPaymentsPrefKey: false});
    final fake = _FakeNotificationService();
    await tester.pumpWidget(harness(fake));
    await tester.pumpAndSettle();

    expect(fake.scheduled, isEmpty);
    expect(fake.cancelled, isEmpty);
    expect(tester.takeException(), isNull);
  });

  // Bug (2) regression: see the matching group in meetings_home_page_test.dart
  // for the full write-up — the same shared `ensureNotificationPermissionForDefaultEnabled`
  // helper backs this page's load path too.
  group('proactive OS permission request on first load with the untouched default (bug 2)', () {
    testWidgets('the first time this page loads with payment alerts still at their untouched default, it proactively requests OS permission', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fake = _FakeNotificationService()..permissionGranted = true;
      await tester.pumpWidget(harness(fake));
      await tester.pumpAndSettle();

      expect(fake.permissionRequests, 1, reason: 'a member who never opened Settings must still get the OS permission prompt the first time the Loans tab loads');
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
      expect(prefs.getBool(kNotifyPaymentsPrefKey), isFalse, reason: 'a denied OS permission must be honestly reflected back into the preference');
      expect(tester.takeException(), isNull);
    });
  });

  // Bug (1) regression: see the matching group in meetings_home_page_test.dart
  // for the full write-up.
  testWidgets('a pending toggle-off cancellation from a previously failed attempt is retried and cleared on load instead of losing it forever', (tester) async {
    SharedPreferences.setMockInitialValues({kNotifyPaymentsPrefKey: false, kNotifyPaymentsCancelPendingKey: true});
    final fake = _FakeNotificationService();
    await tester.pumpWidget(harness(fake));
    await tester.pumpAndSettle();

    expect(fake.cancelled, isNotEmpty, reason: 'the default demo persona has at least one loan to retry-cancel against');
    expect(fake.scheduled, isEmpty, reason: 'payment alerts are still off — only the pending cancellation retries, nothing gets (re)scheduled');
    expect(await loanCancelPending(), isFalse, reason: 'the retry succeeded, so the pending flag must be cleared instead of retrying forever');
    expect(tester.takeException(), isNull);
  });
}
