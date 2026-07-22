import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/types.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';

const _languageNames = <Language, (String, String)>{
  Language.en: ('English', 'English'),
  Language.te: ('తెలుగు', 'Telugu'),
  Language.hi: ('हिंदी', 'Hindi'),
};

class LanguagePage extends StatelessWidget {
  const LanguagePage({super.key});

  // `AppState.setLanguage` applies the change in-memory (and notifies
  // listeners) before it ever touches SharedPreferences, so a persistence
  // failure here never leaves the wrong language on screen — but without
  // this try/catch it also never told the user their choice silently failed
  // to survive a restart, unlike every other preference-save in this app
  // (e.g. settings_page.dart's notification toggles), which show an error
  // SnackBar on a failed save. Capture the messenger/text before the await
  // since the widget's context may be gone by the time it resolves.
  Future<void> _selectLanguage(BuildContext context, Language l) async {
    final messenger = ScaffoldMessenger.of(context);
    final errorText = AppLocalizations.of(context)!.settingsPreferenceError;
    try {
      await context.read<AppState>().setLanguage(l);
    } catch (_) {
      if (context.mounted) messenger.showSnackBar(SnackBar(content: Text(errorText)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: PageHeader(title: l10n.languageTitle),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.languageSubtitle, style: AppTheme.sans(12, color: Neutral.c500)),
          const SizedBox(height: 16),
          AppCard(
            padded: false,
            child: Column(
              children: Language.values.map((l) {
                final selected = l == appState.language;
                final (native, english) = _languageNames[l]!;
                // Which language is currently active is shown only by a
                // check_circle vs. an unchecked radio icon — a screen reader
                // has no built-in way to read that distinction from an Icon,
                // so every row would announce identically regardless of the
                // app's actual current language. `Semantics(selected:)` is
                // the standard flag TalkBack/VoiceOver use to append
                // "selected" (same fix as the bottom nav's active tab).
                return Semantics(
                  selected: selected,
                  button: true,
                  label: native == english ? native : '$native, $english',
                  onTap: () => _selectLanguage(context, l),
                  child: ExcludeSemantics(
                    child: InkWell(
                      onTap: () => _selectLanguage(context, l),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(native, style: AppTheme.sans(15, weight: FontWeight.w700)),
                                if (native != english) Text(english, style: AppTheme.sans(11, color: Neutral.c500)),
                              ],
                            ),
                          ),
                          if (selected) Icon(Icons.check_circle_rounded, color: Brand.c600) else Icon(Icons.radio_button_unchecked_rounded, color: Neutral.c300),
                        ]),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
