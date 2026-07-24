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
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/avatar.dart';
import '../../widgets/section_header.dart';

// Mirrors `meetings_home_page.dart`'s `_statusTones` so this page's own
// status badge and the list row it was reached from always agree — a
// cancelled meeting showing a neutral-gray badge here but a red "cancelled"
// badge there would be a real (if subtle) inconsistency, not just a missed
// nice-to-have, since this is the page a leader lands on right after
// cancelling to confirm it worked.
const _statusTones = <String, BadgeTone>{
  'upcoming': BadgeTone.brand,
  'completed': BadgeTone.success,
  'cancelled': BadgeTone.danger,
};

class MeetingDetailPage extends StatefulWidget {
  final String meetingId;
  // Injectable for tests (mirrors `SettingsPage`'s `notificationService`
  // seam) — defaults to the real on-device implementation.
  final NotificationService? notificationService;
  const MeetingDetailPage({super.key, required this.meetingId, this.notificationService});

  @override
  State<MeetingDetailPage> createState() => _MeetingDetailPageState();
}

class _MeetingDetailPageState extends State<MeetingDetailPage> {
  final _repo = MeetingRepository();
  final _key = GlobalKey<AppAsyncBuilderState<Meeting?>>();
  bool _cancelling = false;

  late final NotificationService _notifications = widget.notificationService ?? LocalNotificationService.instance;

  // `MeetingRepository.setStatus(id, 'cancelled')` was fully wired end-to-end
  // (writes `meetings.status`, RLS-ready) with zero call sites anywhere in
  // `lib/pages` — there was genuinely no way to ever cancel a scheduled
  // meeting, and `meetings_home_page.dart`'s `BadgeTone.danger` styling for
  // 'cancelled' could never actually be reached. Gated the same way this
  // module gates its other leader/staff-only writes (attendance marking,
  // scheduling): `isLeaderOrStaff` in the caller below, never a plain
  // member. Matches this app's existing confirm-dialog style (see
  // `admin_schemes_page.dart`'s "Delete scheme?" dialog / `discard_changes_dialog.dart`):
  // plain `TextButton` for the safe choice, plain `FilledButton` for the
  // one that proceeds.
  Future<void> _cancelMeeting(Meeting meeting) async {
    if (_cancelling) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.meetingDetailCancelDialogTitle),
        content: Text(l10n.meetingDetailCancelDialogContent(DateFormat('dd MMM yyyy').format(meeting.date))),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.meetingDetailKeepMeeting)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.meetingDetailCancelMeeting)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await _repo.setStatus(meeting.id, 'cancelled');
      // Cancels this device's own scheduled reminder for this meeting (if
      // any) right away — waiting for `MeetingsHomePage`'s next load would
      // still work eventually, but only if this device happens to navigate
      // back through the Meetings tab; a leader who cancels and then leaves
      // the app would otherwise keep a stale "starts in an hour" reminder
      // for a meeting that no longer exists. Fire-and-forget (matching
      // `MeetingsHomePage`'s own `unawaited(syncMeetingReminders(...))`) —
      // this is best-effort local housekeeping that must never delay the
      // user-visible confirmation below on a slow/unresponsive platform call.
      //
      // Only ever cancels THIS device's own copy of the reminder — there is
      // no push/FCM backend (see `NotificationService`'s doc comment), so
      // another member's device that already scheduled its own copy of this
      // same reminder is completely unaffected until that device itself
      // reloads the Meetings tab (`MeetingsHomePage._loadAndSyncReminders`)
      // and re-syncs against the now-cancelled status. That's an inherent
      // consequence of the local-only architecture, not something fixable
      // from here — `SettingsPage`'s `settingsNotifLocalOnly` disclosure copy
      // spells this out explicitly so it isn't a silent surprise.
      unawaited(_notifications.cancelMeetingReminder(meeting.id).catchError((_) {}));
      if (mounted) {
        // Reloads this same AppAsyncBuilder<Meeting?> so the badge/action
        // below reflect 'cancelled' immediately, instead of only updating
        // after navigating away and back.
        _key.currentState?.reload();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(SupabaseService.isConfigured ? l10n.meetingDetailCancelledSuccess : l10n.meetingDetailCancelledDemoMode),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.meetingDetailCancelError)));
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isLeaderOrStaff = appState.user.role != Role.member;
    final repo = _repo;
    final meetingId = widget.meetingId;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: PageHeader(title: l10n.meetingDetailTitle),
      body: AppAsyncBuilder<Meeting?>(
        key: _key,
        future: () => repo.fetchById(meetingId),
        builder: (context, meeting) {
          if (meeting == null) {
            return AppEmptyState(icon: Icons.error_outline_rounded, message: l10n.meetingDetailNotFound);
          }
          final shgId = appState.profile?.shgId;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                gradient: const LinearGradient(colors: [Brand.c700, Brand.c600]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Flexible(child: Text(DateFormat('dd MMM yyyy').format(meeting.date), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white))),
                      const SizedBox(width: 8),
                      AppBadge(text: meeting.status, tone: _statusTones[meeting.status] ?? BadgeTone.neutral),
                    ]),
                    const SizedBox(height: 6),
                    Text(meeting.agenda ?? l10n.meetingDetailDefaultTitle, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9))),
                    const SizedBox(height: 6),
                    Text('${meeting.time ?? ''} · ${meeting.venue ?? ''}', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.75))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                onTap: () => context.go(Paths.meetingMom(meetingId)),
                child: Row(children: [
                  Container(width: 40, height: 40, decoration: BoxDecoration(color: Gold.c50, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.description_rounded, color: Gold.c600, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(l10n.meetingDetailMinutesLabel, style: AppTheme.sans(14, weight: FontWeight.w700))),
                  Icon(Icons.chevron_right, color: Neutral.c300),
                ]),
              ),
              // Only offered for a meeting that is both still 'upcoming' AND
              // genuinely hasn't happened yet (`!meeting.hasPassed`). Status
              // alone is not enough to gate this: nothing in the app ever
              // advances a meeting to 'completed' (see `Meeting.hasPassed`'s
              // doc comment), so every meeting that has ever actually taken
              // place — no matter how long ago — still sits at status
              // 'upcoming' forever unless explicitly cancelled. Without the
              // `!meeting.hasPassed` check, a leader could open a meeting
              // from weeks/months ago with real recorded attendance and tap
              // Cancel, which retroactively excludes it from every
              // completed-meeting count / avgAttendancePct / attendance
              // trend / CRP health score that derives from it (they all key
              // off "not cancelled AND date has passed", never the raw
              // status) — a one-tap way to erase real attendance history
              // from her own SHG's stats. An already-cancelled meeting still
              // has nothing left to cancel either, so that half of the gate
              // (`meeting.status == 'upcoming'`) is unchanged.
              if (isLeaderOrStaff && meeting.status == 'upcoming' && !meeting.hasPassed) ...[
                const SizedBox(height: 12),
                AppCard(
                  onTap: _cancelling ? null : () => _cancelMeeting(meeting),
                  child: Row(children: [
                    Container(width: 40, height: 40, decoration: BoxDecoration(color: Accent.red50, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.event_busy_rounded, color: Accent.red600, size: 20)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_cancelling ? l10n.meetingDetailCancelling : l10n.meetingDetailCancelMeeting, style: AppTheme.sans(14, weight: FontWeight.w700, color: Accent.red700))),
                    if (!_cancelling) Icon(Icons.chevron_right, color: Neutral.c300),
                  ]),
                ),
              ],
              const SizedBox(height: 24),
              SectionHeader(title: l10n.meetingDetailAttendanceSection, action: isLeaderOrStaff ? l10n.meetingDetailMarkAction : null, onAction: isLeaderOrStaff ? () => context.go(Paths.meetingAttendance) : null),
              AppAsyncBuilder<List<AttendanceRow>>(
                future: () => repo.fetchAttendance(meetingId, shgId),
                builder: (context, roster) {
                  final present = roster.where((r) => r.present).toList();
                  final absent = roster.where((r) => !r.present).toList();
                  return AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.meetingDetailPresentCount(present.length, roster.length), style: AppTheme.sans(14, weight: FontWeight.w700, color: Brand.c700)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...present.map((r) => Chip(avatar: AppAvatar(name: r.memberName, size: 20), label: Text(r.memberName, style: AppTheme.sans(11)), backgroundColor: Brand.c50)),
                            ...absent.map((r) => Chip(avatar: AppAvatar(name: r.memberName, size: 20), label: Text(r.memberName, style: AppTheme.sans(11, color: Neutral.c400)), backgroundColor: Neutral.c50)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
