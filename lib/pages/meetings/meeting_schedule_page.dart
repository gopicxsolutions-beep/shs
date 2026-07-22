import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../repositories/meeting_repository.dart';
import '../../routes/paths.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../state/unsaved_changes.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/discard_changes_dialog.dart';

class MeetingSchedulePage extends StatefulWidget {
  const MeetingSchedulePage({super.key});
  @override
  State<MeetingSchedulePage> createState() => _MeetingSchedulePageState();
}

class _MeetingSchedulePageState extends State<MeetingSchedulePage> {
  final _venue = TextEditingController();
  final _agenda = TextEditingController();
  final _repo = MeetingRepository();
  DateTime _date = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _time = const TimeOfDay(hour: 16, minute: 0);
  bool _saving = false;
  bool _dirty = false;
  String? _error;

  // Also raises the app-wide `UnsavedChanges` flag that `PageHeader`'s Back
  // button and the bottom nav check before navigating away — see
  // `unsaved_changes.dart` for why this page's own `PopScope` below can't
  // cover those two paths by itself.
  void _markDirty() {
    _dirty = true;
    UnsavedChanges.dirty = true;
  }

  @override
  void dispose() {
    UnsavedChanges.dirty = false;
    _venue.dispose();
    _agenda.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (picked != null && mounted) {
      setState(() {
        _date = picked;
        _markDirty();
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null && mounted) {
      setState(() {
        _time = picked;
        _markDirty();
      });
    }
  }

  Future<void> _submit() async {
    if (_venue.text.trim().isEmpty) {
      setState(() => _error = 'Enter a venue');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final appState = context.read<AppState>();
    try {
      final saved = await _repo.schedule(
        shgId: appState.profile?.shgId,
        date: _date,
        time: _time.format(context),
        venue: _venue.text.trim(),
        agenda: _agenda.text.trim(),
      );
      if (!saved) {
        if (mounted) setState(() => _error = "You're not linked to an SHG, so there's nothing to schedule this meeting for.");
        return;
      }
      if (mounted) {
        // Navigate first, then show on the captured messenger — showing
        // before navigating drops the SnackBar, since context.go() replaces
        // this page's Scaffold before it ever gets a frame to render.
        final messenger = ScaffoldMessenger.of(context);
        context.go(Paths.meetings);
        messenger.showSnackBar(SnackBar(
          content: Text(SupabaseService.isConfigured ? 'Meeting scheduled' : 'Demo mode — meeting not saved (connect Supabase to persist)'),
        ));
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not schedule this meeting. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _pickerTile(String label, String value, VoidCallback onTap) {
    return AppCard(
      onTap: onTap,
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: AppTheme.sans(11, color: Neutral.c500)),
            const SizedBox(height: 4),
            Text(value, overflow: TextOverflow.ellipsis, style: AppTheme.sans(14, weight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(width: 8),
        Icon(Icons.edit_calendar_rounded, color: Brand.c600, size: 20),
      ]),
    );
  }

  // Defense-in-depth for the rare case something genuinely calls
  // `Navigator.pop()` on this page (e.g. if it's ever reached via
  // `context.push()` in the future). Does NOT cover this app's actual
  // navigation triggers today — see `unsaved_changes.dart`.
  Future<void> _handlePop(bool didPop, dynamic result) async {
    if (didPop) return;
    final discard = await confirmDiscardChanges(context);
    if (discard && mounted) {
      UnsavedChanges.dirty = false;
      context.go(Paths.meetings);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: _handlePop,
      child: Scaffold(
      appBar: const PageHeader(title: 'Schedule Meeting'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(child: _pickerTile('Date', DateFormat('dd MMM yyyy').format(_date), _pickDate)),
              const SizedBox(width: 12),
              Expanded(child: _pickerTile('Time', _time.format(context), _pickTime)),
            ]),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Venue', style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _venue,
                    maxLength: 150,
                    textInputAction: TextInputAction.next,
                    style: AppTheme.sans(14),
                    decoration: const InputDecoration(border: InputBorder.none, hintText: 'e.g. Anganwadi Centre, Kondapur', counterText: ''),
                    onChanged: (_) => setState(() {
                      _error = null;
                      _markDirty();
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Agenda', style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _agenda,
                    maxLines: 2,
                    maxLength: 300,
                    textInputAction: TextInputAction.done,
                    style: AppTheme.sans(14),
                    decoration: const InputDecoration(border: InputBorder.none, hintText: 'e.g. Monthly savings review & loan applications', counterText: ''),
                    onChanged: (_) => setState(_markDirty),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: AppTheme.sans(12, color: Accent.red600)),
            ],
            const SizedBox(height: 24),
            AppButton(label: _saving ? 'Scheduling…' : 'Schedule Meeting', fullWidth: true, size: ButtonSize.lg, onPressed: _saving ? null : _submit),
          ],
        ),
      ),
      ),
    );
  }
}
