import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/types.dart';
import '../../routes/paths.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';

const _notifyMeetingsKey = 'settings_notify_meetings';
const _notifySavingsKey = 'settings_notify_savings';
const _notifyAnnouncementsKey = 'settings_notify_announcements';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _loaded = false;
  bool _notifyMeetings = true;
  bool _notifySavings = true;
  bool _notifyAnnouncements = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifyMeetings = prefs.getBool(_notifyMeetingsKey) ?? true;
      _notifySavings = prefs.getBool(_notifySavingsKey) ?? true;
      _notifyAnnouncements = prefs.getBool(_notifyAnnouncementsKey) ?? true;
      _loaded = true;
    });
  }

  Future<void> _setPref(String key, bool value, void Function(bool) apply) async {
    setState(() => apply(value));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: PageHeader(title: l10n.settingsTitle),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(l10n.settingsNotifications, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c500)),
                const SizedBox(height: 12),
                AppCard(
                  padded: false,
                  child: Column(
                    children: [
                      _toggleRow(l10n.settingsNotifMeetingReminders, _notifyMeetings, (v) => _setPref(_notifyMeetingsKey, v, (val) => _notifyMeetings = val)),
                      const Divider(height: 1, color: Neutral.c100),
                      _toggleRow(l10n.settingsNotifPaymentAlerts, _notifySavings, (v) => _setPref(_notifySavingsKey, v, (val) => _notifySavings = val)),
                      const Divider(height: 1, color: Neutral.c100),
                      _toggleRow(l10n.settingsNotifAnnouncements, _notifyAnnouncements, (v) => _setPref(_notifyAnnouncementsKey, v, (val) => _notifyAnnouncements = val)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('General', style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c500)),
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
                const SizedBox(height: 24),
                Text(l10n.settingsPreviewAs, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c500)),
                const SizedBox(height: 6),
                Text('This app lets you preview every role\'s dashboard — switch anytime.', style: AppTheme.sans(11, color: Neutral.c400)),
                const SizedBox(height: 12),
                AppCard(
                  padded: false,
                  child: Column(
                    children: roles.map((r) {
                      final selected = r.id == appState.user.role;
                      return InkWell(
                        onTap: selected ? null : () => appState.setRole(r.id),
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
