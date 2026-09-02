import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/models/types.dart';
import 'package:shg_saathi/routes/paths.dart';
import 'package:shg_saathi/routes/router.dart';
import 'package:shg_saathi/state/app_state.dart';

/// Regression coverage for the first-run language picker: a completely
/// fresh device (no language ever explicitly chosen — see
/// `AppState.languageSelected`) must land on `Paths.languageSelect` before
/// anything else in the auth flow, exactly once, and never again once a
/// language has been picked. Mirrors `deep_link_redirect_test.dart`'s
/// harness (same router/`AppState` contract, no live Supabase needed).
void main() {
  Future<GoRouter> boot(WidgetTester tester, AppState appState, Map<String, Object> prefs) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues(prefs);
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
    return router;
  }

  String currentPath(GoRouter router) => router.routerDelegate.currentConfiguration.uri.path;

  testWidgets('a fresh device with no language chosen lands on the language picker, not splash', (tester) async {
    final appState = AppState();
    await boot(tester, appState, const {});

    expect(appState.languageSelected, isFalse);
    expect(find.text('Choose your language'), findsOneWidget);
  });

  testWidgets('visiting login/otp/an /app deep link directly is redirected to the language picker first', (tester) async {
    final appState = AppState();
    final router = await boot(tester, appState, const {});

    router.go(Paths.login);
    await tester.pumpAndSettle();
    expect(currentPath(router), Paths.languageSelect);

    router.go(Paths.loanDetail('abc123'));
    await tester.pumpAndSettle();
    expect(currentPath(router), Paths.languageSelect, reason: 'must not skip the picker just because the target was a deep link');
  });

  testWidgets('a genuine /app deep link is still captured for replay even though the picker intercepts it first', (tester) async {
    final appState = AppState();
    final router = await boot(tester, appState, const {});

    router.go(Paths.loanDetail('abc123'));
    await tester.pumpAndSettle();

    expect(currentPath(router), Paths.languageSelect);
    expect(appState.pendingDeepLink, Paths.loanDetail('abc123'));
  });

  testWidgets('tapping a language on the picker persists it and proceeds into splash', (tester) async {
    final appState = AppState();
    await boot(tester, appState, const {});

    expect(find.text('Choose your language'), findsOneWidget);

    await tester.tap(find.text('తెలుగు'));
    await tester.pumpAndSettle();

    expect(appState.languageSelected, isTrue);
    expect(appState.language, Language.te);
    expect(find.textContaining('Empowering Women'), findsOneWidget, reason: 'should have moved on to Splash');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('shg_language'), 'te', reason: 'the choice must survive an app restart');
  });

  testWidgets('a device that already chose a language is never sent back to the picker', (tester) async {
    final appState = AppState();
    final router = await boot(tester, appState, const {'shg_language': 'hi'});

    expect(appState.languageSelected, isTrue);
    expect(find.text('Choose your language'), findsNothing);

    router.go(Paths.login);
    await tester.pumpAndSettle();
    expect(currentPath(router), Paths.login);
  });

  testWidgets('an already-authenticated account that predates this feature is not interrupted mid-app', (tester) async {
    final appState = AppState();
    // No `shg_language` — simulates an account that existed before this
    // feature shipped and never happened to visit Settings > Language —
    // but IS already signed in (`shg_session_started`/`shg_authenticated`).
    await boot(tester, appState, const {
      'shg_session_started': true,
      'shg_authenticated': true,
      'shg_role': 'member',
    });

    expect(appState.languageSelected, isFalse);
    expect(find.text('Choose your language'), findsNothing, reason: 'an already-signed-in account must not be yanked out to force a pick it never asked for');
  });
}
