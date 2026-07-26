import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/ai/ai_voice_assistant_page.dart';
import 'package:shg_saathi/pages/savings/savings_entry_page.dart';
import 'package:shg_saathi/routes/paths.dart';
import 'package:shg_saathi/routes/router.dart';
import 'package:shg_saathi/state/app_state.dart';

/// Regression: resolving the addSavings intent shows an answer immediately,
/// then force-navigates to the Savings Entry form 900ms later
/// (`ai_voice_assistant_page.dart`'s `_listen()`). But the mic button
/// re-enables the moment that answer is shown (`_state` becomes `answered`,
/// which isn't `busy`) — well before the 900ms elapses. A member who taps
/// again quickly and asks something else used to still get forcibly
/// navigated to the Savings Entry form 900ms after the *first* (addSavings)
/// request fired, yanking her away from whatever she'd just asked next.
/// Fixed with a request-id guard: the delayed navigation now checks it's
/// still the newest request before firing.
void main() {
  testWidgets(
    're-tapping the mic after an "add savings" answer, before its 900ms navigation delay elapses, cancels the stale navigation',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // A fully-onboarded, authenticated member — matches the prefs shape
      // `all_routes_smoke_test.dart` uses to reach role-gated `/app/*`
      // routes; without these, the router's redirect confines navigation to
      // the auth flow and `Paths.aiVoiceAssistant` is never actually reached.
      SharedPreferences.setMockInitialValues(const {
        'shg_session_started': true,
        'shg_authenticated': true,
        'shg_role': 'member',
      });
      final appState = AppState();
      await appState.init();
      final router = buildRouter(appState);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp.router(
            routerConfig: router,
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
      await tester.pumpAndSettle();

      router.go(Paths.aiVoiceAssistant);
      await tester.pumpAndSettle();
      expect(find.byType(AiVoiceAssistantPage), findsOneWidget);

      final mic = find.byIcon(Icons.mic_rounded);

      // MockVoiceRecognitionService cycles loanDetails, savingsThisMonth,
      // readAnnouncements, addSavings (fixed order) — 3 taps burn through
      // the first three, landing the 4th on addSavings.
      for (var i = 0; i < 3; i++) {
        await tester.tap(mic);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pumpAndSettle();
      }

      // 4th tap: addSavings. Advance just enough to reach `answered` —
      // deliberately NOT pumpAndSettle, which would run the 900ms delay to
      // completion before we get a chance to re-tap.
      await tester.tap(mic);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      await tester.pump();

      // Re-tap immediately — well within the stale request's 900ms window —
      // to ask something else (cycles back to loanDetails).
      await tester.tap(mic);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      await tester.pump();

      // Advance well past the stale 900ms window from the addSavings tap.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.byType(AiVoiceAssistantPage),
        findsOneWidget,
        reason: 'the stale addSavings navigation must not fire once a newer request has superseded it',
      );
      expect(find.byType(SavingsEntryPage), findsNothing);
    },
  );
}
