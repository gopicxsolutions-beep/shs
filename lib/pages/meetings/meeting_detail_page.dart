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
import '../../widgets/avatar.dart';
import '../../widgets/section_header.dart';

class MeetingDetailPage extends StatelessWidget {
  final String meetingId;
  const MeetingDetailPage({super.key, required this.meetingId});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isLeaderOrStaff = appState.user.role != Role.member;
    final repo = MeetingRepository();
    final shgId = appState.profile?.shgId;

    return Scaffold(
      appBar: const PageHeader(title: 'Meeting Detail'),
      body: AppAsyncBuilder<Meeting?>(
        future: () => repo.fetchById(meetingId),
        builder: (context, meeting) {
          if (meeting == null) {
            return const AppEmptyState(icon: Icons.error_outline_rounded, message: 'This meeting could not be found');
          }
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
                      AppBadge(text: meeting.status, tone: BadgeTone.neutral),
                    ]),
                    const SizedBox(height: 6),
                    Text(meeting.agenda ?? 'Meeting', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9))),
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
                  Expanded(child: Text('Minutes of Meeting', style: AppTheme.sans(14, weight: FontWeight.w700))),
                  Icon(Icons.chevron_right, color: Neutral.c300),
                ]),
              ),
              const SizedBox(height: 24),
              SectionHeader(title: 'Attendance', action: isLeaderOrStaff ? 'Mark' : null, onAction: isLeaderOrStaff ? () => context.go(Paths.meetingAttendance) : null),
              AppAsyncBuilder<List<AttendanceRow>>(
                future: () => repo.fetchAttendance(meetingId, shgId),
                builder: (context, roster) {
                  final present = roster.where((r) => r.present).toList();
                  final absent = roster.where((r) => !r.present).toList();
                  return AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${present.length} / ${roster.length} present', style: AppTheme.sans(14, weight: FontWeight.w700, color: Brand.c700)),
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
