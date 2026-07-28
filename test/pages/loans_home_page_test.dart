import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/models/loan.dart';
import 'package:shg_saathi/models/profile.dart';
import 'package:shg_saathi/pages/loans/loans_home_page.dart';
import 'package:shg_saathi/repositories/loan_repository.dart';
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

/// Returns canned cross-SHG data instead of touching a real network —
/// `fetchForMember`/`fetchForShg` return empty (this page's reminder-sync
/// path calls `fetchForMember` in the background even for a staff viewer;
/// a real network call there would throw in this test environment with no
/// live backend configured).
class _FakePlatformWideLoanRepository extends LoanRepository {
  @override
  Future<List<Loan>> fetchAllForStaff() async => const [
        Loan(id: 'loan-1', memberId: 'mem-1', memberName: 'Test Member One', purpose: 'Dairy', amount: 10000, outstanding: 6000, emi: 1000, tenureMonths: 12, status: 'active', shgName: 'Jyothi SHG'),
        Loan(id: 'loan-2', memberId: 'mem-2', memberName: 'Test Member Two', purpose: 'Tailoring', amount: 5000, outstanding: 5000, emi: 0, tenureMonths: 6, status: 'pending', shgName: 'Sneha SHG'),
      ];
  @override
  Future<List<Loan>> fetchForMember(String? memberId) async => const [];
  @override
  Future<List<Loan>> fetchForShg(String? shgId) async => const [];
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
  Future<void> scheduleMeetingReminder({required String meetingId, required DateTime meetingAt, required String title, required String body}) async {}

  @override
  Future<void> cancelMeetingReminder(String meetingId) async {}

  @override
  Future<void> scheduleLoanDueReminder({required String loanId, required DateTime dueDate, required String title, required String body}) async {
    scheduled.add(loanId);
  }

  @override
  Future<void> cancelLoanDueReminder(String loanId) async {
    cancelled.add(loanId);
  }

  @override
  Future<void> showAnnouncementNotification({required String announcementId, required String title, required String notificationTitle}) async {}

  @override
  Future<void> cancelAllScheduled() async {}
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

  // Round 168: crp/clf/admin (no shgId of their own) used to see a
  // permanently-broken zero-state, then an honest-but-dead-end message —
  // now a real platform-wide portfolio. Injects a fake LoanRepository (a
  // real network call isn't available in this test environment) and a real
  // AppState/profile so `SupabaseService.isConfigured && shgId == null`
  // genuinely evaluates true, the same guard condition production code uses.
  group('platform-wide staff portfolio (round 168)', () {
    setUp(() {
      SupabaseService.isConfigured = true;
    });
    tearDown(() {
      SupabaseService.isConfigured = false;
    });

    Future<AppState> staffAppState(String role) async {
      final appState = AppState(
        profileRepository: _FixedProfileRepository(Profile(id: 'staff-$role', name: 'QA $role', role: role, shgId: null)),
        authService: _FakeAuthServiceWithSession(),
      );
      await appState.init();
      return appState;
    }

    for (final staffRole in ['crp', 'clf', 'admin']) {
      testWidgets('a $staffRole account sees a real cross-SHG portfolio, not the old dead-end message', (tester) async {
        SharedPreferences.setMockInitialValues({});
        final appState = await staffAppState(staffRole);
        final fake = _FakeNotificationService();
        await tester.pumpWidget(
          ChangeNotifierProvider<AppState>.value(
            value: appState,
            child: MaterialApp(
              home: LoansHomePage(notificationService: fake, repository: _FakePlatformWideLoanRepository()),
              localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text("Your role isn't linked to a specific SHG — this view doesn't apply"), findsNothing, reason: 'the platform-wide portfolio replaces the old dead-end message');
        expect(find.text('Platform Outstanding'), findsOneWidget);
        expect(find.text('All Loans (All SHGs)'), findsOneWidget);
        // ₹6,000 (loan-1's outstanding, active) — loan-2 is still pending
        // (never disbursed), so its full ₹5,000 must NOT be counted as
        // outstanding debt (see the outstanding-sum comment in build()).
        expect(find.text('₹6,000'), findsOneWidget);
        expect(find.text('Dairy · Jyothi SHG'), findsOneWidget, reason: 'each row must show which SHG it belongs to, not just the member/purpose');
        expect(find.text('Tailoring · Sneha SHG'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a leader account with a real linked SHG still sees its own SHG-scoped view, not the platform-wide one', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final appState = AppState(
        profileRepository: _FixedProfileRepository(const Profile(id: 'leader-1', name: 'QA Leader', role: 'leader', shgId: 'shg-1')),
        authService: _FakeAuthServiceWithSession(),
      );
      await appState.init();
      final fake = _FakeNotificationService();
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: LoansHomePage(notificationService: fake, repository: _FakePlatformWideLoanRepository()),
            localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Platform Outstanding'), findsNothing, reason: 'a leader has her own shgId — she gets the group view, not the platform-wide one, even though the same fake repository is wired in');
      expect(find.text('All Loans (All SHGs)'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
