import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/models/types.dart';
import 'package:shg_saathi/pages/ai/ai_voice_assistant_page.dart';
import 'package:shg_saathi/state/app_state.dart';

/// Regression: the "Try saying" list used to show only 3 of the page's 4
/// recognized intents in every language — it never suggested the addSavings
/// phrase, even though "fill forms through voice" (voice-triggered
/// navigation to the Savings Entry form) is explicitly one of this page's
/// documented capabilities (see the `AiVoiceAssistantPage` class doc
/// comment). A member had no way to discover that command existed unless
/// she guessed it unprompted. Fixed by listing all 4 example phrases, per
/// language, matching `MockVoiceRecognitionService`'s command lists.
void main() {
  Future<void> boot(WidgetTester tester, Language language) async {
    SharedPreferences.setMockInitialValues(const {});
    final appState = AppState();
    await appState.init();
    appState.language = language;
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          home: const AiVoiceAssistantPage(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('English "Try saying" list includes the addSavings example', (tester) async {
    await boot(tester, Language.en);
    expect(find.text('"Add a savings entry"'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Hindi "Try saying" list includes the addSavings example', (tester) async {
    await boot(tester, Language.hi);
    expect(find.text('"बचत जोड़ें"'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Telugu "Try saying" list includes the addSavings example', (tester) async {
    await boot(tester, Language.te);
    expect(find.text('"పొదుపు నమోదు చేయండి"'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
