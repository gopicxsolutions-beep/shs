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

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: PageHeader(title: l10n.languageTitle),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Choose your preferred language for the app', style: AppTheme.sans(12, color: Neutral.c500)),
          const SizedBox(height: 16),
          AppCard(
            padded: false,
            child: Column(
              children: Language.values.map((l) {
                final selected = l == appState.language;
                final (native, english) = _languageNames[l]!;
                return InkWell(
                  onTap: () => context.read<AppState>().setLanguage(l),
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
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
