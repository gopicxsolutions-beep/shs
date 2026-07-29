import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/meeting.dart';
import '../../models/types.dart';
import '../../repositories/meeting_repository.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/avatar.dart';

/// Leader/staff roster screen — defaults to the nearest upcoming meeting (or
/// most recent past one if none is upcoming) since this route isn't
/// parameterized by meeting id; a picker lets the user switch meetings.
class MeetingAttendancePage extends StatefulWidget {
  // Injectable so the platform-wide staff queue (live-mode-only) can be
  // widget-tested against canned cross-SHG data instead of a real network
  // call — mirrors LoanApprovalPage's round-168 `repository` seam.
  final MeetingRepository? repository;
  const MeetingAttendancePage({super.key, this.repository});
  @override
  State<MeetingAttendancePage> createState() => _MeetingAttendancePageState();
}

class _MeetingAttendancePageState extends State<MeetingAttendancePage> {
  late final MeetingRepository _repo = widget.repository ?? MeetingRepository();
  Meeting? _selected;
  final _updating = <String>{};

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final role = appState.user.role;
    final shgId = appState.profile?.shgId;
    final l10n = AppLocalizations.of(context)!;

    // Router-restricted to leader/staff already, but crp/clf/admin have no
    // `profile.shgId` of their own. `meetings_select_shg_or_staff`/
    // `meeting_attendance_self_or_leader` (RLS) have always granted
    // `is_staff()` unrestricted platform-wide read/write — round 168's fix
    // template (Loans, Savings, Livelihood, Financial Ledger) applies here
    // too: a real platform-wide meeting picker instead of an explained-away
    // dead end. `isConfigured` still excludes demo mode, whose simulated
    // identity leaves `shgId` null for every previewed role too.
    //
    // Actual is_staff() (crp/clf/admin), not just `shgId == null` — a LEADER
    // with a null shgId is an unlinked account (see the guard below), never
    // legitimately platform-wide.
    final isPlatformWide = SupabaseService.isConfigured && role != Role.member && role != Role.leader && shgId == null;

    if (SupabaseService.isConfigured && role == Role.leader && shgId == null) {
      return Scaffold(
        appBar: PageHeader(title: l10n.meetingAttendanceTitle),
        body: AppEmptyState(icon: Icons.event_busy_rounded, message: l10n.commonLeaderNoShgMessage),
      );
    }

    return Scaffold(
      appBar: PageHeader(title: l10n.meetingAttendanceTitle),
      body: AppAsyncBuilder<List<Meeting>>(
        future: () => isPlatformWide ? _repo.fetchAllForStaff() : _repo.fetchForShg(shgId),
        builder: (context, meetings) {
          if (meetings.isEmpty) {
            return AppEmptyState(icon: Icons.event_busy_rounded, message: l10n.meetingAttendanceNoMeetings);
          }
          // A cancelled meeting must never be attendance-editable (mirrors
          // `MeetingDetailPage`'s "Cancel Meeting" action, which is itself
          // only offered for a still-genuinely-upcoming meeting) — excluding
          // it here from the picker entirely, not merely from the default
          // selection below, closes the gap where a leader could still pick
          // an already-cancelled meeting from this dropdown and flip its
          // attendance switches after the fact: writing fresh attendance
          // rows tied to a cancelled meeting, visibly inconsistent with that
          // meeting's own detail page (a red "cancelled" badge sitting
          // directly above a live, freshly-editable roster).
          final selectableMeetings = meetings.where((m) => m.status != 'cancelled').toList();
          if (selectableMeetings.isEmpty) {
            return AppEmptyState(icon: Icons.event_busy_rounded, message: l10n.meetingAttendanceNoMeetings);
          }
          // Same fix as meeting_qr_page.dart: `fetchForShg` sorts newest-
          // scheduled-date-first, so naively taking the first 'upcoming'
          // match defaulted to the farthest-future meeting instead of the
          // soonest one whenever more than one was scheduled at once — the
          // dropdown below lets a leader correct it manually, but the wrong
          // default was still a real, easy-to-miss trap for the common case.
          //
          // `!m.hasPassed` also excludes meetings whose date has already
          // gone by, since `status` never actually advances away from
          // 'upcoming' once a meeting happens (see `Meeting.hasPassed`'s
          // doc comment) — without it, a meeting from weeks ago would sort
          // first and keep defaulting the roster to stale history instead
          // of today's meeting, forever, once the SHG has more than one
          // meeting on record.
          final upcomingMeetings = selectableMeetings.where((m) => m.status == 'upcoming' && !m.hasPassed).toList()..sort((a, b) => a.date.compareTo(b.date));
          // If the previously-selected meeting is no longer selectable (e.g.
          // it was the one just cancelled), fall back to the default below
          // instead of leaving `_selected` pointing at a meeting that is no
          // longer among `selectableMeetings`' items (which would otherwise
          // desync `DropdownButton`'s `value` from its own `items`).
          if (_selected != null && !selectableMeetings.any((m) => m.id == _selected!.id)) {
            _selected = null;
          }
          _selected ??= upcomingMeetings.isNotEmpty ? upcomingMeetings.first : selectableMeetings.first;
          final meeting = _selected!;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: AppCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(DateFormat('dd MMM yyyy').format(meeting.date), style: AppTheme.sans(14, weight: FontWeight.w700)),
                            Text(
                              [
                                if ((meeting.agenda ?? meeting.venue) != null) (meeting.agenda ?? meeting.venue)!,
                                if (isPlatformWide && meeting.shgName != null) l10n.meetingAttendanceShgName(meeting.shgName!),
                              ].join(' · '),
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.sans(12, color: Neutral.c500),
                            ),
                          ],
                        ),
                      ),
                      // The left-hand date/agenda text is already `Expanded`,
                      // but this dropdown wasn't wrapped at all — at large
                      // text scale, a platform-wide staff viewer's selected
                      // item (which appends the SHG name) could overflow the
                      // Row well past the screen edge. Live-reproduced at
                      // 2.0x text scale with a long SHG name (gap-hunt
                      // iteration 30) before this fix.
                      Flexible(
                        child: DropdownButton<Meeting>(
                          value: meeting,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: selectableMeetings
                              .map((m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(
                                      isPlatformWide && m.shgName != null ? '${DateFormat('dd MMM').format(m.date)} · ${m.shgName}' : DateFormat('dd MMM').format(m.date),
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTheme.sans(12, weight: FontWeight.w600),
                                    ),
                                  ))
                              .toList(),
                          onChanged: (m) => setState(() => _selected = m),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: AppAsyncBuilder<List<AttendanceRow>>(
                  key: ValueKey(meeting.id),
                  // The selected meeting's OWN shgId, not the viewer's —
                  // for a leader these always coincided (fetchForShg(shgId)
                  // only ever returned her own SHG's meetings), but a
                  // platform-wide staff account's `shgId` is null, and
                  // `fetchAttendance`/`fetchRoster` treat a null shgId as
                  // "no roster" (live mode), which would silently show an
                  // empty roster for a meeting that genuinely has one.
                  future: () => _repo.fetchAttendance(meeting.id, meeting.shgId),
                  builder: (context, roster) {
                    if (roster.isEmpty) {
                      return AppEmptyState(icon: Icons.groups_rounded, message: l10n.meetingAttendanceNoMembers);
                    }
                    final presentCount = roster.where((r) => r.present).length;
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(l10n.meetingAttendancePresentCount(presentCount, roster.length), style: AppTheme.sans(12, weight: FontWeight.w700, color: Brand.c600)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: roster.length,
                            itemBuilder: (context, i) {
                              final row = roster[i];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: AppCard(
                                  padded: false,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    child: Row(children: [
                                      AppAvatar(name: row.memberName, size: 32),
                                      const SizedBox(width: 12),
                                      // MergeSemantics: a leader marking attendance for 20+
                                      // members is a real, frequent, high-stakes action —
                                      // without this, a screen reader landing on the Switch
                                      // announces only "On/Off, switch" with no indication of
                                      // which member it belongs to, same gap already fixed for
                                      // the identical label-next-to-Switch shape in
                                      // settings_page.dart.
                                      Expanded(
                                        child: MergeSemantics(
                                          child: Row(children: [
                                            Expanded(child: Text(row.memberName, style: AppTheme.sans(13, weight: FontWeight.w600))),
                                            Switch(
                                              value: row.present,
                                              activeThumbColor: Brand.c600,
                                              onChanged: _updating.contains(row.memberId)
                                                  ? null
                                                  : (v) async {
                                                      setState(() => _updating.add(row.memberId));
                                                      try {
                                                        await _repo.markAttendance(meeting.id, row.memberId, v);
                                                        if (!context.mounted) return;
                                                        setState(() {
                                                          roster[i] = AttendanceRow(memberId: row.memberId, memberName: row.memberName, present: v);
                                                        });
                                                      } catch (_) {
                                                        if (context.mounted) {
                                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.meetingAttendanceUpdateError)));
                                                        }
                                                      } finally {
                                                        if (context.mounted) setState(() => _updating.remove(row.memberId));
                                                      }
                                                    },
                                            ),
                                          ]),
                                        ),
                                      ),
                                    ]),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
