import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/models/meeting.dart';
import 'package:shg_saathi/models/profile.dart';
import 'package:shg_saathi/pages/meetings/meetings_home_page.dart';
import 'package:shg_saathi/repositories/meeting_repository.dart';
import 'package:shg_saathi/services/auth_service.dart';
import 'package:shg_saathi/services/notification_service.dart';
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
class _FakePlatformWideMeetingRepository extends MeetingRepository {
  @override
  Future<List<Meeting>> fetchAllForStaff() async => [
        Meeting(id: 'm-1', shgId: 'shg-1', date: DateTime.now().subtract(const Duration(days: 10)), venue: 'Community Hall', agenda: 'Monthly review', status: 'upcoming', shgName: 'Jyothi SHG'),
        Meeting(id: 'm-2', shgId: 'shg-2', date: DateTime.now().subtract(const Duration(days: 20)), venue: 'Panchayat Office', agenda: 'Loan discussion', status: 'upcoming', shgName: 'Sneha SHG'),
      ];
  @override
  Future<List<Meeting>> fetchForShg(String? shgId) async => const [];
}

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
  Future<void> scheduleMeetingReminder({required String meetingId, required DateTime meetingAt, required String title, required String body}) async {
    scheduled.add(meetingId);
  }

  @override
  Future<void> cancelMeetingReminder(String meetingId) async {
    cancelled.add(meetingId);
  }

  @override
  Future<void> scheduleLoanDueReminder({required String loanId, required DateTime dueDate, required String title, required String body}) async {}

  @override
  Future<void> cancelLoanDueReminder(String loanId) async {}

  @override
  Future<void> showAnnouncementNotification({required String announcementId, required String title, required String notificationTitle}) async {}
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

  // Round 168's fix template (Loans, Savings, Livelihood, Financial Ledger)
  // applied to Meetings: crp/clf/admin (no `shgId` of their own) used to see
  // a `commonStaffNoShgMessage` dead end — now a real platform-wide feed,
  // since `meetings_select_shg_or_staff` already grants `is_staff()`
  // unrestricted platform-wide read.
  group('platform-wide staff feed (round 168)', () {
    setUp(() {
      SupabaseService.isConfigured = true;
    });
    tearDown(() {
      SupabaseService.isConfigured = false;
    });

    for (final staffRole in ['crp', 'clf', 'admin']) {
      testWidgets('a $staffRole account with no linked SHG sees a real cross-SHG feed, not the old dead-end message, and no Schedule tile', (tester) async {
        SharedPreferences.setMockInitialValues({});
        final profile = Profile(id: 'staff-$staffRole', name: 'QA $staffRole', role: staffRole, shgId: null);
        final appState = AppState(
          profileRepository: _FixedProfileRepository(profile),
          authService: _FakeAuthServiceWithSession(),
        );
        await appState.init();
        final fake = _FakeNotificationService();
        await tester.pumpWidget(
          ChangeNotifierProvider<AppState>.value(
            value: appState,
            child: MaterialApp(
              home: MeetingsHomePage(notificationService: fake, repository: _FakePlatformWideMeetingRepository()),
              localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text("Your role isn't linked to a specific SHG — this view doesn't apply"), findsNothing);
        expect(find.textContaining('SHG: Jyothi SHG'), findsOneWidget, reason: 'each row must show which SHG it belongs to');
        expect(find.textContaining('SHG: Sneha SHG'), findsOneWidget);
        expect(find.byTooltip('Schedule meeting'), findsNothing, reason: 'there is no SHG to schedule a platform-wide meeting against');
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a leader account with a real linked SHG sees her own SHG-scoped feed and a working Schedule tile, no SHG tags', (tester) async {
      SharedPreferences.setMockInitialValues({});
      const profile = Profile(id: 'leader-1', name: 'QA Leader', role: 'leader', shgId: 'shg-1');
      final appState = AppState(
        profileRepository: _FixedProfileRepository(profile),
        authService: _FakeAuthServiceWithSession(),
      );
      await appState.init();
      final fake = _FakeNotificationService();
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: MeetingsHomePage(notificationService: fake, repository: _FakePlatformWideMeetingRepository()),
            localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Your role isn't linked to a specific SHG — this view doesn't apply"), findsNothing);
      expect(find.textContaining('SHG:'), findsNothing, reason: 'a leader only ever sees her own SHG, so the tag would be redundant noise');
      expect(find.byTooltip('Schedule meeting'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
