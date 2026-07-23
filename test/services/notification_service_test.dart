import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shg_saathi/models/announcement.dart';
import 'package:shg_saathi/models/loan.dart';
import 'package:shg_saathi/models/meeting.dart';
import 'package:shg_saathi/services/notification_service.dart';

/// A lightweight fake implementing [NotificationService] — records every
/// call instead of touching a platform channel, exactly as
/// `LocalNotificationService`'s own doc comment says a test needing to
/// observe "what would have been scheduled" should do. Every real device
/// call (`flutter_local_notifications`, `timezone`, `flutter_timezone`) is
/// deliberately not exercised here — this is pure-Dart coverage of the
/// scheduling/cancelling *decisions* (`syncMeetingReminders`,
/// `syncLoanDueReminders`, `notifyNewAnnouncements`), not of the OS actually
/// showing a notification, which needs a real device/emulator.
class _FakeNotificationService implements NotificationService {
  final List<String> scheduledMeetings = [];
  final List<String> cancelledMeetings = [];
  final List<String> scheduledLoans = [];
  final List<String> cancelledLoans = [];
  final List<String> shownAnnouncements = [];
  int permissionRequests = 0;
  bool permissionGranted = true;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<void> scheduleMeetingReminder({required String meetingId, required DateTime meetingAt, required String venue}) async {
    scheduledMeetings.add(meetingId);
  }

  @override
  Future<void> cancelMeetingReminder(String meetingId) async {
    cancelledMeetings.add(meetingId);
  }

  @override
  Future<void> scheduleLoanDueReminder({required String loanId, required DateTime dueDate, required num emiAmount}) async {
    scheduledLoans.add(loanId);
  }

  @override
  Future<void> cancelLoanDueReminder(String loanId) async {
    cancelledLoans.add(loanId);
  }

  @override
  Future<void> showAnnouncementNotification({required String announcementId, required String title}) async {
    shownAnnouncements.add(announcementId);
  }
}

Meeting _meeting({required String id, required DateTime date, String status = 'upcoming'}) => Meeting(
      id: id,
      shgId: 'shg-1',
      date: date,
      time: '10:00 AM',
      venue: 'Test Venue',
      agenda: 'Test agenda',
      status: status,
    );

Loan _loan({required String id, String status = 'active', DateTime? nextDueDate}) => Loan(
      id: id,
      memberId: 'member-1',
      memberName: 'Test Member',
      purpose: 'Test purpose',
      amount: 10000,
      outstanding: 5000,
      emi: 500,
      tenureMonths: 12,
      status: status,
      nextDueDate: nextDueDate,
    );

void main() {
  final now = DateTime.now();
  final future = DateTime(now.year, now.month, now.day + 10);
  final past = DateTime(now.year, now.month, now.day - 10);

  group('syncMeetingReminders', () {
    test('schedules a reminder for an upcoming, not-yet-passed meeting', () async {
      final service = _FakeNotificationService();
      await syncMeetingReminders(service, [_meeting(id: 'm-future', date: future)]);
      expect(service.scheduledMeetings, ['m-future']);
      expect(service.cancelledMeetings, isEmpty);
    });

    test('cancels any reminder for a meeting whose date has already passed, even if status is still "upcoming"', () async {
      // Mirrors `Meeting.hasPassed`'s doc comment: nothing in this app ever
      // advances a meeting's stored status to 'completed', so a genuinely
      // past meeting can still read status == 'upcoming' forever.
      final service = _FakeNotificationService();
      await syncMeetingReminders(service, [_meeting(id: 'm-past', date: past, status: 'upcoming')]);
      expect(service.scheduledMeetings, isEmpty);
      expect(service.cancelledMeetings, ['m-past']);
    });

    test('cancels any reminder for a cancelled meeting', () async {
      final service = _FakeNotificationService();
      await syncMeetingReminders(service, [_meeting(id: 'm-cancelled', date: future, status: 'cancelled')]);
      expect(service.scheduledMeetings, isEmpty);
      expect(service.cancelledMeetings, ['m-cancelled']);
    });

    test('is idempotent across a mixed list, matching exactly the set of upcoming meetings', () async {
      final service = _FakeNotificationService();
      await syncMeetingReminders(service, [
        _meeting(id: 'a', date: future),
        _meeting(id: 'b', date: past),
        _meeting(id: 'c', date: future, status: 'cancelled'),
        _meeting(id: 'd', date: future),
      ]);
      expect(service.scheduledMeetings, ['a', 'd']);
      expect(service.cancelledMeetings, ['b', 'c']);
    });
  });

  group('syncLoanDueReminders', () {
    test('schedules a reminder for an active loan with a known next due date', () async {
      final service = _FakeNotificationService();
      await syncLoanDueReminders(service, [_loan(id: 'l-active', status: 'active', nextDueDate: future)]);
      expect(service.scheduledLoans, ['l-active']);
      expect(service.cancelledLoans, isEmpty);
    });

    test('schedules a reminder for an overdue loan too', () async {
      final service = _FakeNotificationService();
      await syncLoanDueReminders(service, [_loan(id: 'l-overdue', status: 'overdue', nextDueDate: future)]);
      expect(service.scheduledLoans, ['l-overdue']);
    });

    test('cancels for a pending loan with no due date yet', () async {
      final service = _FakeNotificationService();
      await syncLoanDueReminders(service, [_loan(id: 'l-pending', status: 'pending', nextDueDate: null)]);
      expect(service.scheduledLoans, isEmpty);
      expect(service.cancelledLoans, ['l-pending']);
    });

    test('cancels for a closed loan even if a stale next due date is still present', () async {
      final service = _FakeNotificationService();
      await syncLoanDueReminders(service, [_loan(id: 'l-closed', status: 'closed', nextDueDate: future)]);
      expect(service.scheduledLoans, isEmpty);
      expect(service.cancelledLoans, ['l-closed']);
    });
  });

  group('notifyNewAnnouncements', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    Announcement announcement(String id, {DateTime? createdAt}) => Announcement(id: id, title: 'Title $id', category: 'Circular', createdAt: createdAt ?? DateTime.now());

    test('first run on a device seeds the "seen" registry without notifying for pre-existing announcements', () async {
      final service = _FakeNotificationService();
      await notifyNewAnnouncements(service, [announcement('a1'), announcement('a2')]);
      expect(service.shownAnnouncements, isEmpty, reason: 'a member opening Announcements for the first time after this feature ships should not get a backlog of notifications');
    });

    test('a genuinely new announcement (posted after the registry was seeded) does notify', () async {
      final service = _FakeNotificationService();
      await notifyNewAnnouncements(service, [announcement('a1')]);
      expect(service.shownAnnouncements, isEmpty);

      await notifyNewAnnouncements(service, [announcement('a1'), announcement('a2')]);
      expect(service.shownAnnouncements, ['a2']);
    });

    test('never notifies twice for the same announcement id', () async {
      final service = _FakeNotificationService();
      await notifyNewAnnouncements(service, [announcement('a1')]);
      await notifyNewAnnouncements(service, [announcement('a1'), announcement('a2')]);
      expect(service.shownAnnouncements, ['a2']);

      await notifyNewAnnouncements(service, [announcement('a1'), announcement('a2')]);
      expect(service.shownAnnouncements, ['a2'], reason: 'a2 was already notified on the previous call; it must not fire again on a later call that still includes it');
    });
  });

  group('preference reads default to on (matching SettingsPage\'s own default)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('meetingRemindersEnabled defaults to true when never set', () async {
      expect(await meetingRemindersEnabled(), isTrue);
    });

    test('paymentAlertsEnabled defaults to true when never set', () async {
      expect(await paymentAlertsEnabled(), isTrue);
    });

    test('announcementNotificationsEnabled defaults to true when never set', () async {
      expect(await announcementNotificationsEnabled(), isTrue);
    });

    test('meetingRemindersEnabled respects an explicit false', () async {
      SharedPreferences.setMockInitialValues({kNotifyMeetingsPrefKey: false});
      expect(await meetingRemindersEnabled(), isFalse);
    });
  });

  group('cancelAllMeetingReminders / cancelAllLoanDueReminders', () {
    test('cancels every meeting unconditionally, regardless of status or date', () async {
      final service = _FakeNotificationService();
      await cancelAllMeetingReminders(service, [
        _meeting(id: 'm-future', date: future),
        _meeting(id: 'm-past', date: past),
        _meeting(id: 'm-cancelled', date: future, status: 'cancelled'),
      ]);
      expect(service.cancelledMeetings, ['m-future', 'm-past', 'm-cancelled']);
      expect(service.scheduledMeetings, isEmpty);
    });

    test('cancels every loan unconditionally, regardless of status', () async {
      final service = _FakeNotificationService();
      await cancelAllLoanDueReminders(service, [
        _loan(id: 'l-active', status: 'active', nextDueDate: future),
        _loan(id: 'l-closed', status: 'closed'),
      ]);
      expect(service.cancelledLoans, ['l-active', 'l-closed']);
      expect(service.scheduledLoans, isEmpty);
    });
  });

  // Bug (1) regression coverage: the shared "pending cancellation" flags that
  // let `SettingsPage._onMeetingsToggle`/`_onSavingsToggle` mark a
  // toggle-off cancellation as not-yet-confirmed, and let
  // `MeetingsHomePage`/`LoansHomePage` retry it on their next load instead of
  // a transient failure silently and permanently stranding already-scheduled
  // reminders.
  group('meetingCancelPending / loanCancelPending', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to false (not pending) when never set', () async {
      expect(await meetingCancelPending(), isFalse);
      expect(await loanCancelPending(), isFalse);
    });

    test('setMeetingCancelPending(true) is observable via meetingCancelPending(), independently of loanCancelPending', () async {
      await setMeetingCancelPending(true);
      expect(await meetingCancelPending(), isTrue);
      expect(await loanCancelPending(), isFalse, reason: 'meetings and loans track independent pending flags');
    });

    test('setMeetingCancelPending(false) clears it again', () async {
      await setMeetingCancelPending(true);
      expect(await meetingCancelPending(), isTrue);
      await setMeetingCancelPending(false);
      expect(await meetingCancelPending(), isFalse);
    });

    test('setLoanCancelPending round-trips the same way', () async {
      await setLoanCancelPending(true);
      expect(await loanCancelPending(), isTrue);
      await setLoanCancelPending(false);
      expect(await loanCancelPending(), isFalse);
    });
  });

  // Bug (2) regression coverage: OS notification permission used to only
  // ever get requested as a side effect of a user actively flipping a
  // Settings switch — a member who never opens Settings had all three
  // preferences sitting at their enabled default with the underlying OS
  // permission never actually requested, so the OS silently dropped every
  // "scheduled" reminder. `ensureNotificationPermissionForDefaultEnabled` is
  // what `MeetingsHomePage`/`LoansHomePage`/`AnnouncementsHomePage` now call
  // from their own load path to fix that.
  group('ensureNotificationPermissionForDefaultEnabled', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('currently-disabled preference is left alone — nothing to arm permission for', () async {
      final service = _FakeNotificationService();
      final enabled = await ensureNotificationPermissionForDefaultEnabled(service, kNotifyMeetingsPrefKey, false);
      expect(enabled, isFalse);
      expect(service.permissionRequests, 0);
    });

    test('untouched default-enabled preference: first ever call requests OS permission, and grants leave it enabled', () async {
      final service = _FakeNotificationService()..permissionGranted = true;
      final enabled = await ensureNotificationPermissionForDefaultEnabled(service, kNotifyMeetingsPrefKey, true);

      expect(enabled, isTrue);
      expect(service.permissionRequests, 1, reason: 'a member who never opened Settings must still get the OS permission prompt the first time a reminder-backed page loads');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(kNotifyMeetingsPrefKey), isFalse, reason: 'a granted permission must not fabricate an explicit preference value');
    });

    test('untouched default-enabled preference: a denial quietly flips the preference to false instead of silently scheduling reminders the OS will drop', () async {
      final service = _FakeNotificationService()..permissionGranted = false;
      final enabled = await ensureNotificationPermissionForDefaultEnabled(service, kNotifyMeetingsPrefKey, true);

      expect(enabled, isFalse);
      expect(service.permissionRequests, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kNotifyMeetingsPrefKey), isFalse, reason: 'a denied OS permission must be honestly reflected back into the preference, not left showing "on" while nothing can ever actually fire');
    });

    test('a preference the user already explicitly set is never overridden, and never re-requests permission', () async {
      SharedPreferences.setMockInitialValues({kNotifyMeetingsPrefKey: true});
      final service = _FakeNotificationService();
      final enabled = await ensureNotificationPermissionForDefaultEnabled(service, kNotifyMeetingsPrefKey, true);

      expect(enabled, isTrue);
      expect(service.permissionRequests, 0, reason: 'SettingsPage._requestPermissionIfEnabling already handled this the moment the user flipped the switch on');
    });

    test('once ANY page has asked this device and the OS granted, a second/third category reuses that answer instead of asking again', () async {
      final service = _FakeNotificationService()..permissionGranted = true;
      final first = await ensureNotificationPermissionForDefaultEnabled(service, kNotifyMeetingsPrefKey, true);
      final second = await ensureNotificationPermissionForDefaultEnabled(service, kNotifyPaymentsPrefKey, true);

      expect(first, isTrue);
      expect(second, isTrue);
      expect(service.permissionRequests, 1, reason: 'this is a single per-app OS permission, not one per reminder category — a second page must not prompt again');
    });

    test('once ANY page has asked and the OS denied, every other still-untouched default-enabled preference is also honestly turned off without re-prompting', () async {
      final service = _FakeNotificationService()..permissionGranted = false;
      final meetingsEnabled = await ensureNotificationPermissionForDefaultEnabled(service, kNotifyMeetingsPrefKey, true);
      final loansEnabled = await ensureNotificationPermissionForDefaultEnabled(service, kNotifyPaymentsPrefKey, true);
      final announcementsEnabled = await ensureNotificationPermissionForDefaultEnabled(service, kNotifyAnnouncementsPrefKey, true);

      expect(meetingsEnabled, isFalse);
      expect(loansEnabled, isFalse);
      expect(announcementsEnabled, isFalse);
      expect(service.permissionRequests, 1, reason: 'the OS decision is a single per-app grant — Loans/Announcements must not each prompt again after Meetings already got a denial');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kNotifyMeetingsPrefKey), isFalse);
      expect(prefs.getBool(kNotifyPaymentsPrefKey), isFalse);
      expect(prefs.getBool(kNotifyAnnouncementsPrefKey), isFalse);
    });
  });
}
