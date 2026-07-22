import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../models/meeting.dart';
import '../../models/types.dart';
import '../../repositories/meeting_repository.dart';
import '../../routes/paths.dart';
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
  const MeetingsHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isLeaderOrStaff = appState.user.role != Role.member;
    final repo = MeetingRepository();
    final shgId = appState.profile?.shgId;

    return Scaffold(
      appBar: PageHeader(
        title: 'Meetings',
        right: isLeaderOrStaff
            ? IconButton(icon: const Icon(Icons.add_circle_rounded, color: Brand.c600), onPressed: () => context.go(Paths.meetingSchedule), tooltip: 'Schedule meeting')
            : null,
      ),
      body: AppAsyncBuilder<List<Meeting>>(
        future: () => repo.fetchForShg(shgId),
        builder: (context, meetings) {
          // `status` alone isn't reliable here: nothing in the app ever
          // advances a meeting from 'upcoming' to 'completed' (see
          // `Meeting.hasPassed`'s doc comment), so a meeting whose date is
          // long gone would otherwise sit under "Upcoming" forever instead
          // of ever moving to "Past Meetings".
          final upcoming = meetings.where((m) => m.status == 'upcoming' && !m.hasPassed).toList();
          final past = meetings.where((m) => m.status != 'upcoming' || m.hasPassed).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconTile(onTap: () => context.go(Paths.meetingQr), icon: Icons.qr_code_rounded, label: 'Check In', tone: TileTone.brand),
                  if (isLeaderOrStaff) ...[
                    IconTile(onTap: () => context.go(Paths.meetingSchedule), icon: Icons.event_rounded, label: 'Schedule', tone: TileTone.sky),
                    IconTile(onTap: () => context.go(Paths.meetingAttendance), icon: Icons.fact_check_rounded, label: 'Attendance', tone: TileTone.gold),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              if (upcoming.isNotEmpty) ...[
                const SectionHeader(title: 'Upcoming'),
                ...upcoming.map((m) => _meetingCard(context, m)),
                const SizedBox(height: 16),
              ],
              SectionHeader(title: 'Past Meetings'),
              if (past.isEmpty)
                const AppEmptyState(icon: Icons.event_busy_rounded, message: 'No past meetings yet')
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
                Text(m.agenda ?? 'Meeting', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(13, weight: FontWeight.w700)),
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
