import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../models/announcement.dart';
import '../models/loan.dart';
import '../models/meeting.dart';

// SharedPreferences keys for the three Settings toggles
// (`lib/pages/profile/settings_page.dart`) — shared here (not just private to
// that page) so every page that opportunistically syncs reminders
// (`MeetingsHomePage`, `LoansHomePage`, `AnnouncementsHomePage`) reads/writes
// the exact same key instead of each hand-rolling its own string.
const kNotifyMeetingsPrefKey = 'settings_notify_meetings';
const kNotifyPaymentsPrefKey = 'settings_notify_savings';
const kNotifyAnnouncementsPrefKey = 'settings_notify_announcements';

// Set by `SettingsPage._onMeetingsToggle`/`_onSavingsToggle` right before
// attempting to cancel every reminder this device could have previously
// scheduled, and cleared only once that cancellation actually succeeds — see
// `cancelAllMeetingReminders`/`cancelAllLoanDueReminders` and each toggle
// handler's doc comment for the full bug write-up this exists to fix: a
// transient fetch failure used to leave the preference saved as "off" while
// silently stranding already-scheduled reminders forever, since nothing ever
// re-checked a false preference. While this flag reads true,
// `MeetingsHomePage`/`LoansHomePage` retry the cancellation on every load
// (`meetingCancelPending`/`loanCancelPending` below) until it finally
// succeeds, instead of the toggle-off action being able to silently and
// permanently fail.
const kNotifyMeetingsCancelPendingKey = 'settings_notify_meetings_cancel_pending';
const kNotifyPaymentsCancelPendingKey = 'settings_notify_savings_cancel_pending';

// Tracks whether this device has ever asked the OS for notification
// permission (Android 13+'s `POST_NOTIFICATIONS`, iOS's
// `UNUserNotificationCenter` authorization) via
// `ensureNotificationPermissionForDefaultEnabled` below, and what the answer
// was. It's a single flag pair shared across all three reminder types
// (rather than one per type) because the OS permission itself is a single
// per-app grant, not one per notification category — asking again from a
// second/third page the same device would just be a redundant platform-
// channel call for a decision the OS already made.
const kOsNotificationPermissionAskedKey = 'notif_os_permission_asked';
const kOsNotificationPermissionGrantedKey = 'notif_os_permission_granted';

// Key for the "which announcement ids has this device already notified
// about" registry `notifyNewAnnouncements` below reads/writes — see its doc
// comment for why this is needed at all. Public (not a private `_`-prefixed
// key like the pref keys above are private to this file) so tests can seed
// it directly to simulate "this device has already been through its
// first-run seeding pass" without needing to fabricate a genuinely new
// announcement id through the repository.
const kSeenAnnouncementIdsPrefKey = 'notif_seen_announcement_ids';

Future<bool> _prefEnabled(String key) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    // Defaults to true — matches SettingsPage's own default for all three
    // toggles, so a user who never opened Settings still gets reminders by
    // default rather than silently getting none.
    return prefs.getBool(key) ?? true;
  } catch (_) {
    return false;
  }
}

/// Plain boolean flags (default `false` when unset) — used for the
/// "pending cancellation" and "OS permission already decided" bookkeeping
/// below, as opposed to [_prefEnabled]'s user-facing toggles (which default
/// to `true`).
Future<bool> _prefFlag(String key) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> _setPrefFlag(String key, bool value) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  } catch (_) {
    // Best-effort — worst case a pending-cancel/permission-asked flag isn't
    // durably recorded this one time, which only means the corresponding
    // retry/re-ask happens again on some later call rather than being lost
    // in a way that could silently strand something.
  }
}

/// Whether a previous attempt to cancel every scheduled meeting reminder
/// (`SettingsPage._onMeetingsToggle` turning the toggle off) failed partway
/// and still needs retrying — see [kNotifyMeetingsCancelPendingKey]'s doc
/// comment.
Future<bool> meetingCancelPending() => _prefFlag(kNotifyMeetingsCancelPendingKey);
Future<void> setMeetingCancelPending(bool value) => _setPrefFlag(kNotifyMeetingsCancelPendingKey, value);

/// Same idea as [meetingCancelPending], for loan due-date reminders
/// (`SettingsPage._onSavingsToggle`).
Future<bool> loanCancelPending() => _prefFlag(kNotifyPaymentsCancelPendingKey);
Future<void> setLoanCancelPending(bool value) => _setPrefFlag(kNotifyPaymentsCancelPendingKey, value);

/// Abstraction over scheduling/cancelling **local, on-device** notifications
/// — deliberately not push/remote: this app has no Firebase/APNs project
/// wired in, so nothing here can fire once the app has been force-stopped
/// for a while, or from a server while the device is offline. Every
/// notification fired through this service is scheduled by the OS's own
/// local alarm/notification-center API and only ever fires on the device
/// that scheduled it — see `SettingsPage`'s notification copy, which calls
/// this out explicitly so a member doesn't mistake it for a message their
/// leader/CRP can trigger remotely.
///
/// [LocalNotificationService] (real, backed by `flutter_local_notifications`)
/// is the only implementation shipped in `lib/` — unlike a paid/keyed vendor
/// API (see `AiAdvisorService`'s Mock/Edge-Function split), there is no
/// meaningful "fake" version of a local OS notification to ship for demo
/// mode: both demo and live mode want the exact same real on-device
/// scheduling, since neither depends on Supabase being configured. Tests
/// that need to observe *what would have been scheduled* without touching a
/// platform channel provide their own lightweight fake implementing this
/// interface (see `test/services/notification_service_test.dart`).
abstract class NotificationService {
  /// Requests OS notification permission (Android 13+'s `POST_NOTIFICATIONS`
  /// runtime permission; iOS's `UNUserNotificationCenter` authorization
  /// dialog). Returns whether it's granted. Safe to call repeatedly — the OS
  /// only shows the actual prompt once; after the first decision this just
  /// reports it back.
  Future<bool> requestPermission();

  Future<void> scheduleMeetingReminder({required String meetingId, required DateTime meetingAt, required String venue});
  Future<void> cancelMeetingReminder(String meetingId);

  Future<void> scheduleLoanDueReminder({required String loanId, required DateTime dueDate, required num emiAmount});
  Future<void> cancelLoanDueReminder(String loanId);

  /// Shows an immediate (not scheduled) notification for a newly-seen
  /// announcement — see [notifyNewAnnouncements] for how "newly-seen" is
  /// determined.
  Future<void> showAnnouncementNotification({required String announcementId, required String title});
}

/// Real implementation backed by the `flutter_local_notifications` package.
/// A single lazily-created, process-wide instance ([instance]) is shared by
/// every caller rather than each page constructing its own — the plugin's
/// own docs recommend holding one shared instance, and re-`initialize()`ing
/// it repeatedly is wasted platform-channel traffic for no benefit.
class LocalNotificationService implements NotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // A meeting reminder fires this long before the meeting's own scheduled
  // time — long enough to still walk/travel there, short enough to still be
  // "this is about to happen" rather than a same-day-generic reminder.
  static const meetingLeadTime = Duration(minutes: 60);

  // A loan EMI reminder fires this long before `Loan.nextDueDate` — a full
  // day's notice, since (unlike a meeting) there's no fixed time-of-day
  // component to a due *date*, just a calendar day.
  static const loanLeadTime = Duration(days: 1);

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Device timezone lookup failed (unsupported platform, or a name the
      // bundled tz database doesn't recognise, or — in `flutter test` — no
      // platform channel registered at all). Falls back to whatever
      // `tz.local` already defaults to (UTC) rather than crashing; a
      // reminder scheduled in this fallback would fire at the wrong
      // wall-clock offset, but the app keeps working instead of the whole
      // notification feature going down with it.
    }
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false);
    try {
      await _plugin.initialize(settings: const InitializationSettings(android: androidInit, iOS: iosInit));
    } catch (_) {
      // No platform channel registered (e.g. `flutter test`'s headless
      // environment, or an unsupported desktop/web preview target) —
      // every call below is already wrapped by its own try/catch too, so
      // this just avoids re-attempting `initialize()` on every call.
    }
    _initialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    await _ensureInitialized();
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission() ?? false;
        // Best-effort: exact-alarm scheduling needs its own Android 12+
        // permission so reminders fire at their precise minute instead of
        // being deferred by the OS's inexact-alarm batching window.
        // `scheduleMeetingReminder`/`scheduleLoanDueReminder` fall back to
        // inexact scheduling if this was never granted, so a `false`/denied
        // result here doesn't need to fail the whole request.
        try {
          await android.requestExactAlarmsPermission();
        } catch (_) {
          /* not fatal — falls back to inexact scheduling below */
        }
        return granted;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, badge: true, sound: true) ?? false;
      }
    } catch (_) {
      return false;
    }
    // Neither platform implementation resolved (web/desktop/test target) —
    // nothing to gate on; treat as granted so the caller's own preference
    // save still proceeds normally instead of appearing to fail.
    return true;
  }

  @override
  Future<void> scheduleMeetingReminder({required String meetingId, required DateTime meetingAt, required String venue}) async {
    final fireAt = meetingAt.subtract(meetingLeadTime);
    if (!fireAt.isAfter(DateTime.now())) {
      // Already inside (or past) the lead window — nothing useful to remind
      // about anymore. Cancel any stale reminder left over from a previous
      // sync rather than asking the OS to fire one for a time already gone.
      await cancelMeetingReminder(meetingId);
      return;
    }
    await _ensureInitialized();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'meeting_reminders',
        'Meeting reminders',
        channelDescription: 'Reminders shortly before your SHG meetings',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );
    final body = venue.trim().isEmpty ? 'Your SHG meeting starts in about an hour.' : 'Your SHG meeting starts in about an hour at $venue.';
    await _zonedSchedule(_idFor('meeting', meetingId), 'Meeting reminder', body, fireAt, details);
  }

  @override
  Future<void> cancelMeetingReminder(String meetingId) => _cancel(_idFor('meeting', meetingId));

  @override
  Future<void> scheduleLoanDueReminder({required String loanId, required DateTime dueDate, required num emiAmount}) async {
    final fireAt = dueDate.subtract(loanLeadTime);
    if (!fireAt.isAfter(DateTime.now())) {
      await cancelLoanDueReminder(loanId);
      return;
    }
    await _ensureInitialized();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'loan_due_reminders',
        'Payment alerts',
        channelDescription: 'Reminders before your loan EMI due date',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );
    final amountText = emiAmount > 0 ? ' of ₹${emiAmount.round()}' : '';
    await _zonedSchedule(_idFor('loan', loanId), 'Loan payment due tomorrow', 'Your EMI$amountText is due tomorrow.', fireAt, details);
  }

  @override
  Future<void> cancelLoanDueReminder(String loanId) => _cancel(_idFor('loan', loanId));

  @override
  Future<void> showAnnouncementNotification({required String announcementId, required String title}) async {
    await _ensureInitialized();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'announcements',
        'Announcements',
        channelDescription: 'New SHG/federation announcements',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
    );
    try {
      await _plugin.show(id: _idFor('announcement', announcementId), title: 'New announcement', body: title, notificationDetails: details);
    } catch (_) {
      // No platform channel (test/unsupported target) — showing a
      // notification is inherently best-effort; nothing to recover.
    }
  }

  Future<void> _zonedSchedule(int id, String title, String body, DateTime fireAt, NotificationDetails details) async {
    final scheduled = tz.TZDateTime.from(fireAt, tz.local);
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } on PlatformException catch (e) {
      // Android 12+ without the exact-alarm permission throws here instead
      // of scheduling — fall back to inexact scheduling (still fires, just
      // not necessarily at the exact minute) rather than dropping the
      // reminder entirely.
      if (e.code == 'exact_alarms_not_permitted') {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduled,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (_) {
      // No platform channel (test/unsupported target) — best-effort.
    }
  }

  Future<void> _cancel(int id) async {
    await _ensureInitialized();
    try {
      await _plugin.cancel(id: id);
    } catch (_) {
      // No platform channel (test/unsupported target) — nothing to cancel.
    }
  }

  // Deterministic across app restarts and platforms — Dart's built-in
  // `Object.hashCode`/`String.hashCode` is only guaranteed stable for the
  // lifetime of a single isolate run, NOT across restarts, so using it here
  // would occasionally let a `cancel()` after a restart silently miss the
  // notification id that was actually scheduled before the restart (no
  // error — `plugin.cancel()` on a non-matching id just no-ops). A manual
  // FNV-1a-style hash keeps the same `category:key` mapping to the same
  // notification id every time the app runs. Masked to 31 bits (positive
  // `int32`) — `flutter_local_notifications` notification ids are plain
  // platform `int`s (Java `int` on Android).
  static int _idFor(String category, String key) {
    var hash = 0x811c9dc5;
    for (final unit in '$category:$key'.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }
}

/// Schedules/cancels meeting-reminder notifications so the set of pending
/// reminders exactly matches `meetings`: an upcoming, not-yet-passed meeting
/// gets (re)scheduled; anything else (past, cancelled) gets any stale
/// reminder cancelled. Idempotent and safe to call every time the Meetings
/// tab loads (`MeetingsHomePage`) or the toggle is switched on
/// (`SettingsPage`) — scheduling twice for the same meeting just overwrites
/// the same notification id.
Future<void> syncMeetingReminders(NotificationService service, List<Meeting> meetings) async {
  for (final m in meetings) {
    if (m.status == 'upcoming' && !m.hasPassed) {
      await service.scheduleMeetingReminder(meetingId: m.id, meetingAt: m.scheduledAt, venue: m.venue ?? '');
    } else {
      await service.cancelMeetingReminder(m.id);
    }
  }
}

/// Same idea as [syncMeetingReminders], for a member's own loan EMI due
/// dates: only a disbursed, still-owed loan (`active`/`overdue`) with a
/// known `nextDueDate` has a real upcoming due date to remind about.
Future<void> syncLoanDueReminders(NotificationService service, List<Loan> loans) async {
  for (final l in loans) {
    final due = l.nextDueDate;
    if ((l.status == 'active' || l.status == 'overdue') && due != null) {
      await service.scheduleLoanDueReminder(loanId: l.id, dueDate: due, emiAmount: l.emi);
    } else {
      await service.cancelLoanDueReminder(l.id);
    }
  }
}

/// Cancels every reminder this device could have previously scheduled for
/// the given meetings — used both when the meeting-reminders toggle is
/// switched off (`SettingsPage._onMeetingsToggle`) and to retry a previously
/// -failed cancellation the next time `MeetingsHomePage` loads (see
/// [kNotifyMeetingsCancelPendingKey]). Unlike [syncMeetingReminders], this
/// always cancels regardless of a meeting's own status/date — turning
/// reminders off means off, for every meeting, not just the ones that would
/// otherwise still be upcoming.
Future<void> cancelAllMeetingReminders(NotificationService service, List<Meeting> meetings) async {
  for (final m in meetings) {
    await service.cancelMeetingReminder(m.id);
  }
}

/// Same idea as [cancelAllMeetingReminders], for loan due-date reminders
/// (`SettingsPage._onSavingsToggle` / `LoansHomePage`'s retry path).
Future<void> cancelAllLoanDueReminders(NotificationService service, List<Loan> loans) async {
  for (final l in loans) {
    await service.cancelLoanDueReminder(l.id);
  }
}

/// Bug fix: OS notification permission used to only ever get requested as a
/// side effect of a user actively flipping a `SettingsPage` Switch. A member
/// who never opens Settings has all three preferences sitting at their
/// (enabled) default, and `MeetingsHomePage`/`LoansHomePage`/
/// `AnnouncementsHomePage` would schedule/show reminders under that default
/// with the underlying OS permission never actually granted — the OS then
/// silently drops every one, with nothing telling the member why "on"
/// reminders never actually arrive.
///
/// Called from each of those three pages' load path, once per preference.
/// Requests the OS permission — at most once ever across all three reminder
/// types, tracked by [kOsNotificationPermissionAskedKey] (it's a single
/// per-app OS grant, not one per reminder category, so asking again from a
/// second/third page this same device would just be a redundant platform-
/// channel round trip for a decision the OS already made) — and only when
/// `prefKey` has never been explicitly touched by the user: someone who
/// already flipped a Settings switch (on or off) already went through
/// `SettingsPage._requestPermissionIfEnabling`, or made an explicit opt-out
/// choice this must never override.
///
/// If the permission is (or was previously) denied, quietly flips `prefKey`
/// back to `false` — so this device honestly stops "scheduling" reminders
/// that would never actually show, rather than silently continuing to
/// pretend they're on. Returns whether the caller should still treat this
/// preference as enabled.
Future<bool> ensureNotificationPermissionForDefaultEnabled(NotificationService service, String prefKey, bool currentlyEnabled) async {
  if (!currentlyEnabled) return false;
  SharedPreferences prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (_) {
    // Can't tell whether this was an explicit choice or check/record the OS
    // decision — proceed as if still enabled rather than blocking a
    // best-effort permission nudge on this failing.
    return true;
  }
  if (prefs.containsKey(prefKey)) return true; // user already made an explicit choice via Settings.

  final alreadyAsked = prefs.getBool(kOsNotificationPermissionAskedKey) ?? false;
  bool granted;
  if (alreadyAsked) {
    // Another one of these three pages already asked this session/device —
    // reuse that decision instead of prompting the OS again.
    granted = prefs.getBool(kOsNotificationPermissionGrantedKey) ?? true;
  } else {
    granted = await service.requestPermission();
    await _setPrefFlag(kOsNotificationPermissionAskedKey, true);
    await _setPrefFlag(kOsNotificationPermissionGrantedKey, granted);
  }
  if (!granted) {
    try {
      await prefs.setBool(prefKey, false);
    } catch (_) {
      // Best-effort — worst case the preference still reads (default) true
      // and this same check runs again next load.
    }
    return false;
  }
  return true;
}

/// Shows an immediate local notification for every announcement in `items`
/// that this device hasn't already been notified about, then remembers
/// their ids so the same announcement never notifies twice.
///
/// The very first time this runs on a device (no registry saved yet), it
/// seeds the registry with every id currently in `items` **without**
/// notifying for any of them — otherwise a member with, say, 20 months of
/// announcement history would get 20+ notifications the very first time she
/// opens the Announcements tab after this feature ships, indistinguishable
/// from a spam bug.
Future<void> notifyNewAnnouncements(NotificationService service, List<Announcement> items) async {
  SharedPreferences prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (_) {
    return;
  }
  final seenList = prefs.getStringList(kSeenAnnouncementIdsPrefKey);
  final ids = items.map((a) => a.id).toSet();
  if (seenList == null) {
    await prefs.setStringList(kSeenAnnouncementIdsPrefKey, ids.toList());
    return;
  }
  final seen = seenList.toSet();
  final newOnes = items.where((a) => !seen.contains(a.id));
  for (final a in newOnes) {
    await service.showAnnouncementNotification(announcementId: a.id, title: a.title);
  }
  if (newOnes.isNotEmpty) {
    await prefs.setStringList(kSeenAnnouncementIdsPrefKey, {...seen, ...ids}.toList());
  }
}

/// Reads whether the meeting-reminders toggle is on (defaults to on, same as
/// `SettingsPage`'s initial switch value) — used by pages that
/// opportunistically sync reminders on load, so they don't schedule/notify
/// anything the user has explicitly turned off.
Future<bool> meetingRemindersEnabled() => _prefEnabled(kNotifyMeetingsPrefKey);
Future<bool> paymentAlertsEnabled() => _prefEnabled(kNotifyPaymentsPrefKey);
Future<bool> announcementNotificationsEnabled() => _prefEnabled(kNotifyAnnouncementsPrefKey);
