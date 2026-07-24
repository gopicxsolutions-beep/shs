import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/meeting.dart';
import '../../repositories/meeting_repository.dart';
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
  const MeetingAttendancePage({super.key});
  @override
  State<MeetingAttendancePage> createState() => _MeetingAttendancePageState();
}

class _MeetingAttendancePageState extends State<MeetingAttendancePage> {
  final _repo = MeetingRepository();
  Meeting? _selected;
  final _updating = <String>{};

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final shgId = appState.profile?.shgId;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: PageHeader(title: l10n.meetingAttendanceTitle),
      body: AppAsyncBuilder<List<Meeting>>(
        future: () => _repo.fetchForShg(shgId),
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
                            Text(meeting.agenda ?? meeting.venue ?? '', overflow: TextOverflow.ellipsis, style: AppTheme.sans(12, color: Neutral.c500)),
                          ],
                        ),
                      ),
                      DropdownButton<Meeting>(
                        value: meeting,
                        underline: const SizedBox(),
                        items: selectableMeetings
                            .map((m) => DropdownMenuItem(value: m, child: Text(DateFormat('dd MMM').format(m.date), style: AppTheme.sans(12, weight: FontWeight.w600))))
                            .toList(),
                        onChanged: (m) => setState(() => _selected = m),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: AppAsyncBuilder<List<AttendanceRow>>(
                  key: ValueKey(meeting.id),
                  future: () => _repo.fetchAttendance(meeting.id, shgId),
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
