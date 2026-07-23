import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/meeting.dart';
import '../../models/types.dart';
import '../../repositories/meeting_repository.dart';
import '../../routes/paths.dart';
import '../../services/notification_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/list_row.dart';
import '../../widgets/section_header.dart';

const _statusTones = <String, BadgeTone>{
  'upcoming': BadgeTone.brand,
  'completed': BadgeTone.success,
  'cancelled': BadgeTone.danger,
};

class MeetingsHomePage extends StatelessWidget {
  // Injectable for tests (mirrors `SettingsPage`'s `notificationService`
  // seam) — defaults to the real on-device implementation.
  final NotificationService? notificationService;
  const MeetingsHomePage({super.key, this.notificationService});

  /// Fetches this SHG's meetings and, best-effort and without blocking the
  /// list from rendering, brings this device's scheduled meeting reminders
  /// in line with them (see `syncMeetingReminders`'s doc comment) — this is
  /// what makes a newly-scheduled or newly-cancelled meeting's reminder
  /// actually (re)schedule/cancel: every navigation back to this tab
  /// (`context.go()` always remounts a fresh page per this app's navigation
  /// convention — see CLAUDE.md) re-runs this fetch from scratch.
  ///
  /// Before deciding, this also (a) proactively requests the OS notification
  /// permission the first time this ever loads with the preference still at
  /// its untouched, enabled-by-default state — see
  /// `ensureNotificationPermissionForDefaultEnabled`'s doc comment — instead
  /// of only ever asking reactively when a member happens to visit Settings,
  /// and (b) retries a previous toggle-off cancellation that failed
  /// part-way (`meetingCancelPending`) instead of leaving it silently and
  /// permanently stranded — see `SettingsPage._onMeetingsToggle`'s doc
  /// comment for the full bug write-up both of these fix.
  ///
  /// Bug fix: the permission-check-and-sync step below used to be `await`ed
  /// before returning `meetings` to `AppAsyncBuilder`, so the list this
  /// method is documented as "without blocking...rendering" was in fact
  /// held behind the real on-device OS permission round trip — which, in an
  /// environment with no native counterpart to ever answer it (this app's
  /// own `flutter test` suite, whenever this page's default real
  /// [LocalNotificationService.instance] is exercised without an injected
  /// fake), never resolves at all and hung `pumpAndSettle` forever. Firing
  /// it off with [unawaited] instead means the already-fetched `meetings`
  /// render immediately no matter how long (or whether) that ever resolves.
  Future<List<Meeting>> _loadAndSyncReminders(MeetingRepository repo, String? shgId, NotificationService notifications) async {
    final meetings = await repo.fetchForShg(shgId);
    unawaited(_syncReminders(notifications, meetings));
    return meetings;
  }

  Future<void> _syncReminders(NotificationService notifications, List<Meeting> meetings) async {
    final enabled = await ensureNotificationPermissionForDefaultEnabled(notifications, kNotifyMeetingsPrefKey, await meetingRemindersEnabled());
    if (enabled) {
      await syncMeetingReminders(notifications, meetings);
    } else if (await meetingCancelPending()) {
      await _retryPendingCancellation(notifications, meetings);
    }
  }

  /// Retries a cancellation `SettingsPage._onMeetingsToggle` started but
  /// couldn't confirm succeeded (e.g. a flaky connection at the moment the
  /// toggle was switched off) — cancels every one of this SHG's meeting
  /// reminders again and, only on success, clears the pending flag so this
  /// doesn't keep retrying forever once it's actually done.
  Future<void> _retryPendingCancellation(NotificationService notifications, List<Meeting> meetings) async {
    try {
      await cancelAllMeetingReminders(notifications, meetings);
      await setMeetingCancelPending(false);
    } catch (_) {
      // Still pending — tried again the next time this page loads.
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isLeaderOrStaff = appState.user.role != Role.member;
    final repo = MeetingRepository();
    final shgId = appState.profile?.shgId;
    final notifications = notificationService ?? LocalNotificationService.instance;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: PageHeader(
        title: l10n.meetingsHomeTitle,
        right: isLeaderOrStaff
            ? IconButton(icon: const Icon(Icons.add_circle_rounded, color: Brand.c600), onPressed: () => context.go(Paths.meetingSchedule), tooltip: l10n.meetingsHomeScheduleTooltip)
            : null,
      ),
      body: AppAsyncBuilder<List<Meeting>>(
        future: () => _loadAndSyncReminders(repo, shgId, notifications),
        builder: (context, meetings) {
          // `status` alone isn't reliable here: nothing in the app ever
          // advances a meeting from 'upcoming' to 'completed' (see
          // `Meeting.hasPassed`'s doc comment), so a meeting whose date is
          // long gone would otherwise sit under "Upcoming" forever instead
          // of ever moving to "Past Meetings". `status != 'upcoming'`
          // already covers a meeting cancelled via `MeetingDetailPage`'s
          // "Cancel Meeting" action too — cancelling moves it into "Past
          // Meetings" (showing its red "cancelled" badge) immediately, even
          // if its date hasn't arrived yet, rather than leaving a cancelled
          // meeting sitting under "Upcoming" looking like it's still on.
          final upcoming = meetings.where((m) => m.status == 'upcoming' && !m.hasPassed).toList();
          final past = meetings.where((m) => m.status != 'upcoming' || m.hasPassed).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconTile(onTap: () => context.go(Paths.meetingQr), icon: Icons.qr_code_rounded, label: l10n.meetingsHomeCheckIn, tone: TileTone.brand),
                  if (isLeaderOrStaff) ...[
                    IconTile(onTap: () => context.go(Paths.meetingSchedule), icon: Icons.event_rounded, label: l10n.meetingsHomeScheduleLabel, tone: TileTone.sky),
                    IconTile(onTap: () => context.go(Paths.meetingAttendance), icon: Icons.fact_check_rounded, label: l10n.meetingsHomeAttendanceLabel, tone: TileTone.gold),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              if (upcoming.isNotEmpty) ...[
                SectionHeader(title: l10n.meetingsHomeUpcoming),
                ...upcoming.map((m) => _meetingCard(context, m)),
                const SizedBox(height: 16),
              ],
              SectionHeader(title: l10n.meetingsHomePastMeetings),
              if (past.isEmpty)
                AppEmptyState(icon: Icons.event_busy_rounded, message: l10n.meetingsHomeNoPastMeetings)
              else
                AppCard(
                  padded: false,
                  child: Column(
                    children: past.map((m) {
                      return AppListRow(
                        title: DateFormat('dd MMM yyyy').format(m.date),
                        subtitle: m.agenda ?? m.venue ?? '',
                        trailing: AppBadge(text: m.status, tone: _statusTones[m.status] ?? BadgeTone.neutral),
                        onTap: () => context.go(Paths.meetingDetail(m.id)),
                      );
                    }).toList(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _meetingCard(BuildContext context, Meeting m) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: () => context.go(Paths.meetingDetail(m.id)),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: Brand.c50, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            // Fixed 48x48 calendar-style date badge — at a scaled-up
            // accessibility text size the month + day text no longer fits
            // that height. FittedBox scales the pair down together to
            // stay inside the square instead of overflowing it (same fix
            // as the identical badge in leader_dashboard.dart).
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(DateFormat('MMM').format(m.date), style: AppTheme.sans(9, weight: FontWeight.w700, color: Brand.c700)),
                Text(DateFormat('d').format(m.date), style: AppTheme.sans(15, weight: FontWeight.w700, color: Brand.c700)),
              ]),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.agenda ?? l10n.meetingsHomeDefaultTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(13, weight: FontWeight.w700)),
                Text('${m.time ?? ''} · ${m.venue ?? ''}', style: AppTheme.sans(11, color: Neutral.c500)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Neutral.c300),
        ]),
      ),
    );
  }
}
