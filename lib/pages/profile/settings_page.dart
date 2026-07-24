import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/types.dart';
import '../../repositories/loan_repository.dart';
import '../../repositories/meeting_repository.dart';
import '../../routes/paths.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';

const _notifyMeetingsKey = kNotifyMeetingsPrefKey;
const _notifySavingsKey = kNotifyPaymentsPrefKey;
const _notifyAnnouncementsKey = kNotifyAnnouncementsPrefKey;

class SettingsPage extends StatefulWidget {
  // Injectable for tests (mirrors `SupportVoicePage`'s `service` seam) —
  // defaults to the real on-device implementation. There's no Mock variant
  // to swap in for demo vs. live mode (see `NotificationService`'s doc
  // comment for why): both modes want the same real local scheduling: tests
  // that need to observe *what would have been scheduled* instead supply a
  // small fake here that records calls instead of touching a platform
  // channel.
  final NotificationService? notificationService;
  // Injectable for tests that need to reproduce a fetch failure inside the
  // toggle-off cancellation path (see `_onMeetingsToggle`/`_onSavingsToggle`)
  // — a plain subclass overriding `fetchForShg`/`fetchForMember` to throw is
  // the only way to exercise that path deterministically, since neither
  // repository's dual-mode (`_live` / mock) fetch ever throws on its own.
  // Defaults to the real repository, exactly like `notificationService`.
  final MeetingRepository? meetingRepository;
  final LoanRepository? loanRepository;
  const SettingsPage({super.key, this.notificationService, this.meetingRepository, this.loanRepository});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _loaded = false;
  bool _notifyMeetings = true;
  bool _notifySavings = true;
  bool _notifyAnnouncements = true;
  bool _switchingRole = false;

  late final NotificationService _notifications = widget.notificationService ?? LocalNotificationService.instance;
  late final MeetingRepository _meetingRepository = widget.meetingRepository ?? MeetingRepository();
  late final LoanRepository _loanRepository = widget.loanRepository ?? LoanRepository();

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _notifyMeetings = prefs.getBool(_notifyMeetingsKey) ?? true;
        _notifySavings = prefs.getBool(_notifySavingsKey) ?? true;
        _notifyAnnouncements = prefs.getBool(_notifyAnnouncementsKey) ?? true;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _setPref(String key, bool value, void Function(bool) apply) async {
    setState(() => apply(value));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {
      if (mounted) {
        setState(() => apply(!value));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.settingsPreferenceError)));
      }
    }
  }

  /// Requests OS notification permission the moment a toggle is switched
  /// *on* — this is the one real, user-visible moment to ask (rather than
  /// e.g. at app launch for a permission the member may never actually use),
  /// and matches how the equivalent camera/mic permissions in this app are
  /// requested lazily at first use. Surfaces a one-time note if denied so a
  /// member understands why reminders that get "scheduled" below won't
  /// actually show — silently doing nothing would look like the toggle
  /// itself is broken.
  Future<void> _requestPermissionIfEnabling(bool enabling) async {
    if (!enabling) return;
    final granted = await _notifications.requestPermission();
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.settingsNotifPermissionDenied)),
      );
    }
  }

  /// Turning meeting reminders on/off doesn't just flip a preference bit —
  /// it should take effect immediately against whatever meetings already
  /// exist, not only the next time `MeetingsHomePage` happens to reload.
  ///
  /// Turning ON schedules a reminder for every still-upcoming meeting,
  /// best-effort: a failed fetch (e.g. offline) leaves the saved preference
  /// alone — `MeetingsHomePage` opportunistically re-syncs from the same
  /// preference on its own next load, so nothing is permanently lost by a
  /// transient failure there.
  ///
  /// Turning OFF is deliberately NOT best-effort in the same way, because
  /// the failure mode is asymmetric: a failed re-sync while turning ON just
  /// means a reminder that should exist doesn't yet (annoying, but the next
  /// load fixes it and nothing fires that shouldn't). A failed cancellation
  /// while turning OFF, if silently swallowed, leaves the preference saved
  /// as "off" while the device still has a live, already-scheduled OS
  /// reminder that will actually fire — contradicting what the member just
  /// explicitly turned off, with a UI that looks like it succeeded. So this
  /// marks [setMeetingCancelPending] BEFORE attempting the cancellation
  /// (surviving an app kill/crash mid-attempt) and only clears it once every
  /// reminder is confirmed cancelled; `MeetingsHomePage`'s load path retries
  /// it for as long as the flag stays set (see `meetingCancelPending`), and
  /// a failure here also surfaces a visible, actionable error immediately
  /// instead of a silently-succeeding-looking toggle.
  Future<void> _onMeetingsToggle(bool value, String? shgId) async {
    await _setPref(_notifyMeetingsKey, value, (val) => _notifyMeetings = val);
    await _requestPermissionIfEnabling(value);
    if (value) {
      await setMeetingCancelPending(false);
      try {
        final meetings = await _meetingRepository.fetchForShg(shgId);
        await syncMeetingReminders(_notifications, meetings);
      } catch (_) {
        /* best-effort, see doc comment above */
      }
      return;
    }
    await setMeetingCancelPending(true);
    try {
      final meetings = await _meetingRepository.fetchForShg(shgId);
      await cancelAllMeetingReminders(_notifications, meetings);
      await setMeetingCancelPending(false);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.settingsNotifCancelPendingError)),
        );
      }
      // Left pending on purpose — see doc comment above: MeetingsHomePage
      // retries this the next time it loads instead of it being lost.
    }
  }

  /// Same idea as [_onMeetingsToggle] (including the not-best-effort
  /// turning-OFF behavior — see its doc comment), for this member's own loan
  /// EMI due dates (`LoanRepository.fetchForMember`, not `fetchForShg` — a
  /// payment due-date reminder is inherently personal, not shared across the
  /// SHG the way meetings/announcements are).
  Future<void> _onSavingsToggle(bool value, String? memberId) async {
    await _setPref(_notifySavingsKey, value, (val) => _notifySavings = val);
    await _requestPermissionIfEnabling(value);
    if (value) {
      await setLoanCancelPending(false);
      try {
        final loans = await _loanRepository.fetchForMember(memberId);
        await syncLoanDueReminders(_notifications, loans);
      } catch (_) {
        /* best-effort, see _onMeetingsToggle's doc comment */
      }
      return;
    }
    await setLoanCancelPending(true);
    try {
      final loans = await _loanRepository.fetchForMember(memberId);
      await cancelAllLoanDueReminders(_notifications, loans);
      await setLoanCancelPending(false);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.settingsNotifCancelPendingError)),
        );
      }
      // Left pending on purpose — LoansHomePage retries this the next time
      // it loads instead of it being lost.
    }
  }

  /// Announcement notifications are event-driven (fired the next time
  /// `AnnouncementsHomePage` loads and diffs against the ids it has already
  /// notified about — see `notifyNewAnnouncements`'s doc comment), not a
  /// fixed set of ids to schedule/cancel up front the way meeting/loan due
  /// dates are. So beyond saving the preference and (dis)arming the OS
  /// permission, there's nothing further to do here on toggle.
  Future<void> _onAnnouncementsToggle(bool value) async {
    await _setPref(_notifyAnnouncementsKey, value, (val) => _notifyAnnouncements = val);
    await _requestPermissionIfEnabling(value);
  }

  Future<void> _switchRole(AppState appState, Role role) async {
    if (_switchingRole) return;
    setState(() => _switchingRole = true);
    try {
      await appState.setRole(role);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.settingsRoleSwitchError)));
      }
    } finally {
      if (mounted) setState(() => _switchingRole = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: PageHeader(title: l10n.settingsTitle),
      body: !_loaded
          ? Center(child: Semantics(label: l10n.commonLoading, liveRegion: true, child: const CircularProgressIndicator()))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(l10n.settingsNotifications, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c500)),
                const SizedBox(height: 4),
                Text(l10n.settingsNotifLocalOnly, style: AppTheme.sans(11, color: Neutral.c400)),
                const SizedBox(height: 12),
                AppCard(
                  padded: false,
                  child: Column(
                    children: [
                      _toggleRow(l10n.settingsNotifMeetingReminders, _notifyMeetings, (v) => _onMeetingsToggle(v, appState.profile?.shgId)),
                      const Divider(height: 1, color: Neutral.c100),
                      _toggleRow(l10n.settingsNotifPaymentAlerts, _notifySavings, (v) => _onSavingsToggle(v, appState.profile?.id)),
                      const Divider(height: 1, color: Neutral.c100),
                      _toggleRow(l10n.settingsNotifAnnouncements, _notifyAnnouncements, (v) => _onAnnouncementsToggle(v)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(l10n.settingsGeneralSection, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c500)),
                const SizedBox(height: 12),
                AppCard(
                  padded: false,
                  child: InkWell(
                    onTap: () => context.go(Paths.profileLanguage),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(children: [
                        Icon(Icons.language_rounded, size: 18, color: Brand.c600),
                        const SizedBox(width: 12),
                        Expanded(child: Text(l10n.settingsLanguage, style: AppTheme.sans(13, weight: FontWeight.w600))),
                        Text(_languageLabel(appState.language), style: AppTheme.sans(12, color: Neutral.c500)),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded, color: Neutral.c300),
                      ]),
                    ),
                  ),
                ),
                // Live accounts have a real, backend-authorized role (set at
                // onboarding / by an admin) — self-selecting any role here,
                // including Administrator, would be a client-side privilege
                // escalation with nothing on the server to stop it. This
                // preview switcher only makes sense in demo mode, where
                // there's no real backend and no real permissions to escalate.
                if (!SupabaseService.isConfigured) ...[
                  const SizedBox(height: 24),
                  Text(l10n.settingsPreviewAs, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c500)),
                  const SizedBox(height: 6),
                  Text(l10n.settingsPreviewRoleDescription, style: AppTheme.sans(11, color: Neutral.c400)),
                  const SizedBox(height: 12),
                  AppCard(
                    padded: false,
                    child: Column(
                      children: roles.map((r) {
                        final selected = r.id == appState.user.role;
                        return InkWell(
                          onTap: selected || _switchingRole ? null : () => _switchRole(appState, r.id),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(children: [
                              Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, size: 18, color: selected ? Brand.c600 : Neutral.c300),
                              const SizedBox(width: 12),
                              Expanded(child: Text(r.label, style: AppTheme.sans(13, weight: selected ? FontWeight.w700 : FontWeight.w500))),
                            ]),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Center(child: Text('${l10n.settingsAppVersion}: NavaSakhi v1.0.0', style: AppTheme.sans(11, color: Neutral.c400))),
              ],
            ),
    );
  }

  String _languageLabel(Language l) => switch (l) { Language.en => 'English', Language.te => 'తెలుగు', Language.hi => 'हिंदी' };

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label, style: AppTheme.sans(13, weight: FontWeight.w600))),
          Switch(value: value, onChanged: onChanged, activeThumbColor: Brand.c600),
        ]),
      );
}
