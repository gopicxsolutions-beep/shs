import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/types.dart';
import '../../repositories/meeting_repository.dart';
import '../../routes/paths.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../state/unsaved_changes.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
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
    final l10n = AppLocalizations.of(context)!;
    if (_venue.text.trim().isEmpty) {
      setState(() => _error = l10n.meetingScheduleEnterVenueError);
      return;
    }
    final appState = context.read<AppState>();
    final shgId = appState.profile?.shgId;
    // Resolved before any `await` below (not inline at the call site) —
    // `_time.format(context)` used `context` after the duplicate-meeting
    // confirm dialog's own async gap, which `flutter analyze`'s
    // `use_build_context_synchronously` correctly flagged: the combined
    // `if (proceed != true || !mounted) return;` guard further down isn't
    // narrow enough for the analyzer to trust a context use several lines
    // later still. Same fix shape as the two identical bugs already found
    // this session in settings_page.dart.
    final timeStr = _time.format(context);
    // A leader had no warning at all if she scheduled two meetings for the
    // same SHG on the same calendar day — nothing client- or server-side
    // checked for it, and both then show up independently in the Upcoming
    // list and the attendance picker with no reconciliation between them.
    // A soft confirm (not a hard block) since a genuine second meeting on
    // the same day — an emergency session alongside the regular one — is a
    // real, if unusual, need.
    if (shgId != null) {
      final existing = await _repo.fetchForShg(shgId);
      final sameDayMatch = existing.where((m) => m.status != 'cancelled' && m.date.year == _date.year && m.date.month == _date.month && m.date.day == _date.day);
      if (sameDayMatch.isNotEmpty && mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.meetingScheduleDuplicateConfirmTitle),
            content: SingleChildScrollView(child: Text(l10n.meetingScheduleDuplicateConfirmMessage(DateFormat('dd MMM yyyy').format(_date)))),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.actionCancel)),
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.meetingScheduleDuplicateConfirmButton)),
            ],
          ),
        );
        if (proceed != true || !mounted) return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await _repo.schedule(
        shgId: shgId,
        date: _date,
        time: timeStr,
        venue: _venue.text.trim(),
        agenda: _agenda.text.trim(),
      );
      if (!saved) {
        if (mounted) setState(() => _error = l10n.meetingScheduleNoShgError);
        return;
      }
      if (mounted) {
        // Navigate first, then show on the captured messenger — showing
        // before navigating drops the SnackBar, since context.go() replaces
        // this page's Scaffold before it ever gets a frame to render.
        final messenger = ScaffoldMessenger.of(context);
        context.go(Paths.meetings);
        messenger.showSnackBar(SnackBar(
          content: Text(SupabaseService.isConfigured ? l10n.meetingScheduleSuccess : l10n.meetingScheduleDemoMode),
        ));
      }
    } catch (_) {
      if (mounted) setState(() => _error = l10n.meetingScheduleError);
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
    final l10n = AppLocalizations.of(context)!;
    final shgId = context.select<AppState, String?>((s) => s.profile?.shgId);
    final role = context.select<AppState, Role>((s) => s.user.role);

    // Router-restricted to leader/staff already, but crp/clf/admin have no
    // `profile.shgId` of their own — without this guard they could fill out
    // the whole form before discovering `meetingScheduleNoShgError` only at
    // submit time (that check stays in `_submit` as a harmless fallback for
    // the rare case shgId changes mid-session). `isConfigured` excludes demo
    // mode, whose simulated identity leaves `shgId` null for every role.
    //
    // A LEADER hitting this is a genuinely broken/unlinked account (see
    // AppState.completeProfileSetup's doc comment) — `commonStaffNoShgMessage`
    // ("your role isn't linked to a specific SHG") is written for crp/clf/
    // admin, for whom that's expected and by design, not an error to fix.
    if (SupabaseService.isConfigured && shgId == null) {
      return Scaffold(
        appBar: PageHeader(title: l10n.meetingScheduleTitle),
        body: AppEmptyState(icon: Icons.groups_rounded, message: role == Role.leader ? l10n.commonLeaderNoShgMessage : l10n.commonStaffNoShgMessage),
      );
    }

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: _handlePop,
      child: Scaffold(
      appBar: PageHeader(title: l10n.meetingScheduleTitle),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(child: _pickerTile(l10n.meetingScheduleDateLabel, DateFormat('dd MMM yyyy').format(_date), _pickDate)),
              const SizedBox(width: 12),
              Expanded(child: _pickerTile(l10n.meetingScheduleTimeLabel, _time.format(context), _pickTime)),
            ]),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.meetingScheduleVenueLabel, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _venue,
                    maxLength: 150,
                    textInputAction: TextInputAction.next,
                    style: AppTheme.sans(14),
                    decoration: InputDecoration(border: InputBorder.none, hintText: l10n.meetingScheduleVenueHint, counterText: ''),
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
                  Text(l10n.meetingScheduleAgendaLabel, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _agenda,
                    maxLines: 2,
                    maxLength: 300,
                    textInputAction: TextInputAction.done,
                    style: AppTheme.sans(14),
                    decoration: InputDecoration(border: InputBorder.none, hintText: l10n.meetingScheduleAgendaHint, counterText: ''),
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
            AppButton(label: _saving ? l10n.meetingScheduleSubmitting : l10n.meetingScheduleTitle, fullWidth: true, size: ButtonSize.lg, onPressed: _saving ? null : _submit),
          ],
        ),
      ),
      ),
    );
  }
}
