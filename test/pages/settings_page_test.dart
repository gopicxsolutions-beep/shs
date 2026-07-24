import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/models/loan.dart';
import 'package:shg_saathi/models/meeting.dart';
import 'package:shg_saathi/pages/profile/settings_page.dart';
import 'package:shg_saathi/repositories/loan_repository.dart';
import 'package:shg_saathi/repositories/meeting_repository.dart';
import 'package:shg_saathi/services/notification_service.dart';
import 'package:shg_saathi/state/app_state.dart';

/// Always throws — reproduces "the Supabase fetch briefly fails" from
/// inside `SettingsPage._onMeetingsToggle`/`_onSavingsToggle` deterministically,
/// since neither repository's real dual-mode fetch (demo-mode mock data,
/// live-mode Supabase query) ever throws on its own in a test environment.
class _ThrowingMeetingRepository extends MeetingRepository {
  @override
  Future<List<Meeting>> fetchForShg(String? shgId) async {
    throw Exception('simulated flaky connection');
  }
}

class _ThrowingLoanRepository extends LoanRepository {
  @override
  Future<List<Loan>> fetchForMember(String? memberId) async {
    throw Exception('simulated flaky connection');
  }
}

/// Records calls instead of touching a platform channel — see
/// `LocalNotificationService`'s doc comment for why this is the intended way
/// to test what this page schedules/cancels, without a real device/emulator.
class _FakeNotificationService implements NotificationService {
  int permissionRequests = 0;
  bool permissionGranted = true;
  final List<String> cancelledMeetings = [];
  final List<String> cancelledLoans = [];

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<void> scheduleMeetingReminder({required String meetingId, required DateTime meetingAt, required String venue}) async {}

  @override
  Future<void> cancelMeetingReminder(String meetingId) async {
    cancelledMeetings.add(meetingId);
  }

  @override
  Future<void> scheduleLoanDueReminder({required String loanId, required DateTime dueDate, required num emiAmount}) async {}

  @override
  Future<void> cancelLoanDueReminder(String loanId) async {
    cancelledLoans.add(loanId);
  }

  @override
  Future<void> showAnnouncementNotification({required String announcementId, required String title}) async {}
}

/// Regression coverage for SettingsPage's `_loadPrefs()`/`_setPref()` fixes.
/// Before the fix, `_loadPrefs()` had no error handling at all — `_loaded`
/// only ever became true on the success path, so the page would be stuck on
/// its CircularProgressIndicator forever if SharedPreferences ever threw.
/// `_setPref()` was fire-and-forget from a Switch.onChanged with no
/// rollback, so a save failure left the toggle showing a value that was
/// never actually persisted, with zero user feedback.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget harness() => ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: MaterialApp(
          home: const SettingsPage(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );

  testWidgets('settings load past the spinner and toggling a switch persists without exception', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing, reason: '_loadPrefs() must resolve _loaded=true even under error, not hang forever');
    expect(find.byType(Switch), findsWidgets);

    final aSwitch = find.byType(Switch).first;
    final before = tester.widget<Switch>(aSwitch).value;
    await tester.tap(aSwitch);
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(aSwitch).value, !before);
    expect(tester.takeException(), isNull);
  });

  Widget wiredHarness(NotificationService fake) => ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: MaterialApp(
          home: SettingsPage(notificationService: fake),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );

  testWidgets('turning meeting reminders OFF does not request OS notification permission', (tester) async {
    final fake = _FakeNotificationService();
    await tester.pumpWidget(wiredHarness(fake));
    await tester.pumpAndSettle();

    final meetingsSwitch = find.byType(Switch).first;
    expect(tester.widget<Switch>(meetingsSwitch).value, isTrue, reason: 'defaults to on');
    await tester.tap(meetingsSwitch);
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(meetingsSwitch).value, isFalse);
    expect(fake.permissionRequests, 0, reason: 'disabling a reminder type has nothing to ask OS permission for');
    expect(tester.takeException(), isNull);
  });

  testWidgets('turning meeting reminders back ON requests OS notification permission', (tester) async {
    SharedPreferences.setMockInitialValues({'settings_notify_meetings': false});
    final fake = _FakeNotificationService();
    await tester.pumpWidget(wiredHarness(fake));
    await tester.pumpAndSettle();

    final meetingsSwitch = find.byType(Switch).first;
    expect(tester.widget<Switch>(meetingsSwitch).value, isFalse);
    await tester.tap(meetingsSwitch);
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(meetingsSwitch).value, isTrue);
    expect(fake.permissionRequests, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('turning payment alerts OFF cancels reminders for this member\'s current demo-mode loans', (tester) async {
    final fake = _FakeNotificationService();
    await tester.pumpWidget(wiredHarness(fake));
    await tester.pumpAndSettle();

    // Payment alerts is the second toggle row (Meeting reminders, Payment
    // alerts, Announcements — see SettingsPage.build()).
    final paymentsSwitch = find.byType(Switch).at(1);
    expect(tester.widget<Switch>(paymentsSwitch).value, isTrue, reason: 'defaults to on');
    await tester.tap(paymentsSwitch);
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(paymentsSwitch).value, isFalse);
    // Demo mode's default persona (no live profile) has active/overdue loans
    // in lib/data/loans.dart, so disabling should cancel at least one.
    expect(fake.cancelledLoans, isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the notifications section explains reminders are local-only, not push', (tester) async {
    await tester.pumpWidget(wiredHarness(_FakeNotificationService()));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.settingsNotifLocalOnly), findsOneWidget);
  });

  // Bug (3) regression: the local-only disclosure must explicitly cover the
  // cross-device staleness implication — a cancelled meeting only cancels
  // this device's own reminder, so another member's device can still show a
  // stale one until she reopens the Meetings tab.
  testWidgets('the local-only disclosure explicitly covers cross-device staleness after a meeting is cancelled', (tester) async {
    await tester.pumpWidget(wiredHarness(_FakeNotificationService()));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(l10n.settingsNotifLocalOnly, contains('cancelled'));
    expect(l10n.settingsNotifLocalOnly, contains('another member'));
  });

  Widget wiredHarnessWithRepos(NotificationService fake, {MeetingRepository? meetingRepository, LoanRepository? loanRepository}) => ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: MaterialApp(
          home: SettingsPage(notificationService: fake, meetingRepository: meetingRepository, loanRepository: loanRepository),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );

  // Bug (1) regression — exact scenario from the report: "a member on a
  // flaky connection switches Meeting reminders OFF right as the Supabase
  // fetch briefly fails". Before the fix, the preference was already saved
  // as false by the time the fetch failed, the failure was silently
  // swallowed by an empty catch block, and nothing ever cancelled the
  // already-scheduled device reminders again — the switch showed OFF and
  // stayed OFF forever while the stale reminders kept firing on schedule.
  group('turning meeting reminders OFF while the fetch fails (bug 1)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('shows a visible error and leaves the cancellation pending for retry, instead of silently succeeding', (tester) async {
      final fake = _FakeNotificationService();
      await tester.pumpWidget(wiredHarnessWithRepos(fake, meetingRepository: _ThrowingMeetingRepository()));
      await tester.pumpAndSettle();

      final meetingsSwitch = find.byType(Switch).first;
      expect(tester.widget<Switch>(meetingsSwitch).value, isTrue, reason: 'defaults to on');
      await tester.tap(meetingsSwitch);
      await tester.pumpAndSettle();

      // The Switch itself still shows OFF — the preference bit is saved
      // independently of the (failing) cancellation attempt.
      expect(tester.widget<Switch>(meetingsSwitch).value, isFalse);
      // But the cancellation itself never actually happened...
      expect(fake.cancelledMeetings, isEmpty, reason: 'the repository fetch backing the cancellation attempt failed');
      // ...so the member must SEE that it failed, rather than a
      // silently-succeeding-looking toggle.
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.settingsNotifCancelPendingError), findsOneWidget);
      // Crucially: the failure must not be silently and permanently lost —
      // a pending-cancel marker must survive so MeetingsHomePage can retry
      // it automatically the next time it loads (see
      // meetings_home_page_test.dart's matching retry coverage).
      expect(await meetingCancelPending(), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('once the fetch succeeds again, retrying the same toggle actually cancels and clears the pending flag', (tester) async {
      final fake = _FakeNotificationService();
      // First attempt fails (throwing repo) and leaves the flag pending.
      await tester.pumpWidget(wiredHarnessWithRepos(fake, meetingRepository: _ThrowingMeetingRepository()));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(await meetingCancelPending(), isTrue);

      // Turning it back ON clears the pending flag (nothing left to cancel
      // — the member now wants reminders on again).
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(await meetingCancelPending(), isFalse);
    });

    testWidgets('the equivalent payment-alerts (loan) toggle-off has the same not-silently-lose-it fix', (tester) async {
      final fake = _FakeNotificationService();
      await tester.pumpWidget(wiredHarnessWithRepos(fake, loanRepository: _ThrowingLoanRepository()));
      await tester.pumpAndSettle();

      final paymentsSwitch = find.byType(Switch).at(1);
      expect(tester.widget<Switch>(paymentsSwitch).value, isTrue, reason: 'defaults to on');
      await tester.tap(paymentsSwitch);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(paymentsSwitch).value, isFalse);
      expect(fake.cancelledLoans, isEmpty);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.settingsNotifCancelPendingError), findsOneWidget);
      expect(await loanCancelPending(), isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}
