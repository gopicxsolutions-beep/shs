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
import '../../widgets/qr_scanner_sheet.dart';

/// Self check-in for the current member. Scanning any QR code (the meeting
/// itself doesn't render/print one in this app yet — that's a separate
/// "generate a QR" feature not built here) opens the camera and checks the
/// member in on the first successful scan; the "Check In" tap remains as
/// the always-available fallback for when no camera/printed QR exists.
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
    // A real memberId is required to persist in live mode, but demo mode
    // never has one (AppState.profile is always null there) and its
    // markAttendance() no-ops regardless of the id passed — so only bail
    // out when live mode actually needs a real id to write.
    if (memberId == null && SupabaseService.isConfigured) return;
    setState(() => _checkingIn = true);
    try {
      await _repo.markAttendance(meeting.id, memberId ?? 'demo-member', true);
      if (mounted) {
        setState(() => _checkedIn = true);
        if (!SupabaseService.isConfigured) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demo mode — check-in not saved (connect Supabase to persist)')));
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not check you in. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _checkingIn = false);
    }
  }

  Future<void> _scanAndCheckIn(Meeting meeting, String? memberId) async {
    final code = await showQrScanner(context, title: 'Scan Attendance QR', instructions: 'Point your camera at the QR code displayed at the venue');
    if (code == null || !mounted) return;
    await _checkIn(meeting, memberId);
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
                if (!_checkedIn) ...[
                  AppButton(
                    label: _checkingIn ? 'Scanning…' : 'Scan QR to Check In',
                    icon: Icons.qr_code_scanner_rounded,
                    fullWidth: true,
                    size: ButtonSize.lg,
                    onPressed: _checkingIn ? null : () => _scanAndCheckIn(meeting, memberId),
                  ),
                  const SizedBox(height: 10),
                  AppButton(
                    label: _checkingIn ? 'Checking in…' : 'Check In Without Scanning',
                    variant: ButtonVariant.outline,
                    fullWidth: true,
                    onPressed: _checkingIn ? null : () => _checkIn(meeting, memberId),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
