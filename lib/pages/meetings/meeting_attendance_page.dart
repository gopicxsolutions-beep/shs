import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../models/meeting.dart';
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

    return Scaffold(
      appBar: const PageHeader(title: 'Attendance'),
      body: AppAsyncBuilder<List<Meeting>>(
        future: () => _repo.fetchForShg(shgId),
        builder: (context, meetings) {
          if (meetings.isEmpty) {
            return const AppEmptyState(icon: Icons.event_busy_rounded, message: 'No meetings to mark attendance for');
          }
          _selected ??= meetings.where((m) => m.status == 'upcoming').isNotEmpty
              ? meetings.firstWhere((m) => m.status == 'upcoming')
              : meetings.first;
          final meeting = _selected!;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: AppCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(DateFormat('dd MMM yyyy').format(meeting.date), style: AppTheme.sans(14, weight: FontWeight.w700)),
                          Text(meeting.agenda ?? meeting.venue ?? '', style: AppTheme.sans(12, color: Neutral.c500)),
                        ],
                      ),
                      DropdownButton<Meeting>(
                        value: meeting,
                        underline: const SizedBox(),
                        items: meetings
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
                      return const AppEmptyState(icon: Icons.groups_rounded, message: 'No members to mark attendance for');
                    }
                    final presentCount = roster.where((r) => r.present).length;
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text('$presentCount / ${roster.length} present', style: AppTheme.sans(12, weight: FontWeight.w700, color: Brand.c600)),
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
                                        onChanged: !SupabaseService.isConfigured || _updating.contains(row.memberId)
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
                                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update attendance. Please try again.')));
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
