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
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';

/// Self check-in for the current member. A real camera-based QR scan needs a
/// camera plugin (none is in pubspec.yaml yet); this implements the actual
/// attendance-marking logic behind a simple "Check In" tap instead of faking
/// a scanner UI that wouldn't really scan anything.
class MeetingQrPage extends StatefulWidget {
  const MeetingQrPage({super.key});
  @override
  State<MeetingQrPage> createState() => _MeetingQrPageState();
}

class _MeetingQrPageState extends State<MeetingQrPage> {
  final _repo = MeetingRepository();
  bool _checkingIn = false;
  bool _checkedIn = false;

  Future<void> _checkIn(Meeting meeting, String? memberId) async {
    if (memberId == null) return;
    setState(() => _checkingIn = true);
    try {
      await _repo.markAttendance(meeting.id, memberId, true);
      if (mounted) setState(() => _checkedIn = true);
    } finally {
      if (mounted) setState(() => _checkingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final shgId = appState.profile?.shgId;
    final memberId = appState.profile?.id;

    return Scaffold(
      appBar: const PageHeader(title: 'Meeting Check-In'),
      body: AppAsyncBuilder<List<Meeting>>(
        future: () => _repo.fetchForShg(shgId),
        builder: (context, meetings) {
          final upcoming = meetings.where((m) => m.status == 'upcoming');
          if (upcoming.isEmpty) {
            return const AppEmptyState(icon: Icons.event_busy_rounded, message: 'No meeting scheduled to check in to right now');
          }
          final meeting = upcoming.first;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 24),
                Container(
                  width: 96, height: 96,
                  decoration: BoxDecoration(color: Brand.c50, borderRadius: BorderRadius.circular(28)),
                  alignment: Alignment.center,
                  child: Icon(_checkedIn ? Icons.check_circle_rounded : Icons.qr_code_scanner_rounded, size: 44, color: Brand.c600),
                ),
                const SizedBox(height: 20),
                Text(_checkedIn ? "You're checked in!" : 'Check in to this meeting', style: AppTheme.display(18), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(meeting.agenda ?? 'Meeting', style: AppTheme.sans(14, weight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('${DateFormat('dd MMM yyyy').format(meeting.date)} · ${meeting.time ?? ''} · ${meeting.venue ?? ''}', style: AppTheme.sans(12, color: Neutral.c500)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (!_checkedIn)
                  AppButton(
                    label: _checkingIn ? 'Checking in…' : 'Check In',
                    fullWidth: true,
                    size: ButtonSize.lg,
                    onPressed: !SupabaseService.isConfigured || _checkingIn ? null : () => _checkIn(meeting, memberId),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
