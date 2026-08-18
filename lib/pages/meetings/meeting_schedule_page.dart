import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/shg.dart';
import '../../models/types.dart';
import '../../repositories/meeting_repository.dart';
import '../../repositories/shg_repository.dart';
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
  // Injectable for tests (mirrors `MeetingAttendancePage`'s round-168
  // `repository` seam) — defaults to the real repositories.
  final MeetingRepository? repository;
  final ShgRepository? shgRepository;
  const MeetingSchedulePage({super.key, this.repository, this.shgRepository});
  @override
  State<MeetingSchedulePage> createState() => _MeetingSchedulePageState();
}

class _MeetingSchedulePageState extends State<MeetingSchedulePage> {
  final _venue = TextEditingController();
  final _agenda = TextEditingController();
  late final MeetingRepository _repo = widget.repository ?? MeetingRepository();
  late final ShgRepository _shgRepo = widget.shgRepository ?? ShgRepository();
  DateTime _date = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _time = const TimeOfDay(hour: 16, minute: 0);
  bool _saving = false;
  bool _dirty = false;
  String? _error;

  // crp/clf/admin have no `profile.shgId` of their own (platform-wide by
  // design — see `MeetingAttendancePage`'s identical `isPlatformWide` doc
  // comment). This page used to hard-block every such account behind
  // `commonStaffNoShgMessage`, on the reasoning that scheduling is "a
  // leader's own SHG action" — but `meeting_attendance_page.dart` already
  // grants staff full platform-wide read/write over attendance (RLS:
  // `meetings_insert_leader_or_staff`/`meeting_attendance_insert_self_or_
  // leader` both have an unconditional `is_staff()` branch), and a real SHG
  // with no leader yet on record (a real, live-observed state — a brand-new
  // SHG onboarded by a CRP before its leader account exists) can otherwise
  // NEVER get a meeting scheduled by anyone, which permanently blocks the
  // entire attendance feature for that SHG despite staff being fully
  // authorized to operate it. Lets a platform-wide staff account pick which
  // SHG to schedule for instead of being turned away outright.
  List<ShgProfile> _shgs = [];
  String? _selectedShgId;
  bool _loadingShgs = false;

  Future<void> _loadShgs() async {
    setState(() => _loadingShgs = true);
    final page = await _shgRepo.fetchAllShgs();
    if (mounted) {
      setState(() {
        _shgs = page.items;
        _loadingShgs = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    final role = appState.user.role;
    if (SupabaseService.isConfigured && role != Role.member && role != Role.leader && appState.profile?.shgId == null) {
      _loadShgs();
    }
  }

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
    final role = appState.user.role;
    final isPlatformWide = SupabaseService.isConfigured && role != Role.member && role != Role.leader && appState.profile?.shgId == null;
    final shgId = isPlatformWide ? _selectedShgId : appState.profile?.shgId;
    if (isPlatformWide && shgId == null) {
      setState(() => _error = l10n.meetingScheduleSelectShgError);
      return;
    }
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

    // A LEADER with no `profile.shgId` is a genuinely broken/unlinked
    // account (see `AppState.completeProfileSetup`'s doc comment) — still a
    // hard block, `commonLeaderNoShgMessage` explains why. `isConfigured`
    // excludes demo mode, whose simulated identity leaves `shgId` null for
    // every role.
    if (SupabaseService.isConfigured && role == Role.leader && shgId == null) {
      return Scaffold(
        appBar: PageHeader(title: l10n.meetingScheduleTitle),
        body: AppEmptyState(icon: Icons.groups_rounded, message: l10n.commonLeaderNoShgMessage),
      );
    }

    // crp/clf/admin have no `profile.shgId` of their own — platform-wide by
    // design, not a broken account (mirrors `MeetingAttendancePage`'s own
    // `isPlatformWide`). This used to hard-block every such account here
    // too, on the theory that scheduling is purely a leader's own-SHG
    // action — but staff are already fully authorized (RLS:
    // `meetings_insert_leader_or_staff`'s unconditional `is_staff()`
    // branch) to schedule for ANY SHG, and a real SHG with no leader
    // account yet on record could otherwise never get a meeting scheduled
    // by anyone, permanently blocking attendance for it. Offer an SHG
    // picker instead of turning staff away.
    final isPlatformWide = SupabaseService.isConfigured && role != Role.member && role != Role.leader && shgId == null;

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
            if (isPlatformWide) ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.meetingScheduleShgLabel, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
                    const SizedBox(height: 8),
                    _loadingShgs
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : _shgs.isEmpty
                            // Same `DropdownButtonFormField`-silently-disables
                            // gap already fixed in savings_entry_page.dart —
                            // an empty `items` list leaves the field looking
                            // interactive but inert, with no explanation.
                            ? Text(l10n.adminShgsEmptyState, style: AppTheme.sans(13, color: Neutral.c500))
                            : DropdownButtonFormField<String>(
                                initialValue: _selectedShgId,
                                isExpanded: true,
                                decoration: InputDecoration(border: InputBorder.none, hintText: l10n.meetingScheduleSelectShgHint),
                                items: _shgs.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis))).toList(),
                                onChanged: (v) => setState(() {
                                  _selectedShgId = v;
                                  _error = null;
                                  _markDirty();
                                }),
                              ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
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
