import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../models/meeting.dart';
import '../../repositories/meeting_repository.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';

class AttendanceReportPage extends StatelessWidget {
  const AttendanceReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final memberId = appState.profile?.id;
    final shgId = appState.profile?.shgId;
    final repo = MeetingRepository();

    return Scaffold(
      appBar: const PageHeader(title: 'Attendance Report'),
      body: AppAsyncBuilder<List<MemberAttendanceRecord>>(
        future: () => repo.fetchAttendanceHistory(memberId, shgId),
        builder: (context, records) {
          if (records.isEmpty) {
            return const AppEmptyState(icon: Icons.event_available_rounded, message: 'No completed meetings yet');
          }
          final presentCount = records.where((r) => r.present).length;
          final pct = (presentCount / records.length) * 100;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Overall Attendance', style: AppTheme.sans(13, weight: FontWeight.w700)),
                      Text('${pct.toStringAsFixed(0)}%', style: AppTheme.sans(15, weight: FontWeight.w700, color: Brand.c600)),
                    ]),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(value: pct / 100, minHeight: 8, backgroundColor: Neutral.c100, color: Brand.c500),
                    ),
                    const SizedBox(height: 6),
                    Text('$presentCount of ${records.length} meetings attended', style: AppTheme.sans(11, color: Neutral.c500)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...records.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padded: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(DateFormat('dd MMM yyyy').format(r.meetingDate), style: AppTheme.sans(13, weight: FontWeight.w700)),
                              if (r.venue != null) Text(r.venue!, style: AppTheme.sans(11, color: Neutral.c500)),
                            ],
                          ),
                          Icon(
                            r.present ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            color: r.present ? Accent.emerald700 : Accent.red500,
                            size: 20,
                          ),
                        ]),
                      ),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }
}
