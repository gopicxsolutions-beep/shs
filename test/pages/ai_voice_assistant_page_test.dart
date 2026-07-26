import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/models/types.dart';
import 'package:shg_saathi/pages/ai/ai_voice_assistant_page.dart';
import 'package:shg_saathi/state/app_state.dart';

/// Regression test: the page's own chrome (title, listening-state label,
/// "You said"/"Assistant"/"Try saying" labels) used to be hardcoded English
/// literals, ignoring both the app's display language and this page's own
/// language ChoiceChip — even though every *answer* the page produces
/// already correctly followed `_language` via
/// `lookupAppLocalizations(_localeFor(_language))`. A Hindi/Telugu-speaking
/// member would have seen a fully localized answer inside a page that still
/// said "Listening…" in English. Fixed by routing every one of these
/// strings through that same locale source.
void main() {
  Future<void> boot(WidgetTester tester, AppState appState) async {
    SharedPreferences.setMockInitialValues(const {});
    await appState.init();
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

  testWidgets('opens localized to the member\'s Telugu app-language preference, not hardcoded English', (tester) async {
    final appState = AppState();
    appState.language = Language.te;
    await boot(tester, appState);

    expect(find.text('వాయిస్ అసిస్టెంట్'), findsOneWidget, reason: 'page title must follow the language, not stay "Voice Assistant"');
    expect(find.text('కమాండ్ చెప్పడానికి నొక్కండి'), findsOneWidget, reason: 'idle-state label must be localized');
    expect(find.text('Voice Assistant'), findsNothing);
    expect(find.text('Tap to speak a command'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching the page\'s own language chip re-localizes the title and state label live', (tester) async {
    final appState = AppState();
    appState.language = Language.en;
    await boot(tester, appState);

    expect(find.text('Voice Assistant'), findsOneWidget);
    expect(find.text('Tap to speak a command'), findsOneWidget);

    await tester.tap(find.text('हिंदी'));
    await tester.pump();

    expect(find.text('वॉइस असिस्टेंट'), findsOneWidget, reason: 'switching the ChoiceChip must re-render the title in the newly selected language');
    expect(find.text('कमांड बोलने के लिए टैप करें'), findsOneWidget);
    expect(find.text('Voice Assistant'), findsNothing);
    expect(find.text('Tap to speak a command'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
