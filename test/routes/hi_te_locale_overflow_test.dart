import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/routes/paths.dart';
import 'package:shg_saathi/routes/router.dart';
import 'package:shg_saathi/state/app_state.dart';

/// Verifies real (not just longer-English) Hindi/Telugu translated strings
/// don't cause a RenderFlex overflow at 2.0x text scale — a real gap this
/// suite otherwise has: `text_scale_stress_test.dart`/
/// `narrow_screen_large_text_stress_test.dart` stress text scale but never
/// set a non-English locale, so they gave false confidence about exactly
/// this scenario. An adversarial review of the i18n completion pass found
/// genuine overflow here (admin_dashboard.dart's pending-review "Review"
/// link and recent-activity time badge, member_dashboard.dart's "Pay Now"
/// link, leader_dashboard.dart's "View" link, and
/// scheme_eligibility_page.dart's eligibility badge — each a trailing
/// action-link/badge in a `Row` not wrapped in `Flexible`, so a longer
/// Hindi/Telugu translation pushed the preceding `Expanded` sibling past
/// zero width) — all fixed by wrapping the trailing widget in `Flexible`
/// with `TextOverflow.ellipsis`, the same pattern already used elsewhere in
/// this codebase (see `AppListRow`'s own trailing-widget handling).
void main() {
  Future<GoRouter> boot(WidgetTester tester, Map<String, Object> prefs, Locale locale) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues(prefs);
    final appState = AppState();
    await appState.init();
    final router = buildRouter(appState);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp.router(
          routerConfig: router,
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2.0)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> goAndCheck(WidgetTester tester, GoRouter router, String path, String label) async {
    router.go(path);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: '$label ($path) threw during build/layout');
  }

  const adminPrefs = {'shg_session_started': true, 'shg_authenticated': true, 'shg_role': 'admin'};
  const leaderPrefs = {'shg_session_started': true, 'shg_authenticated': true, 'shg_role': 'leader'};
  const memberPrefs = {'shg_session_started': true, 'shg_authenticated': true, 'shg_role': 'member'};

  final routes = <String, ({String path, Map<String, Object> prefs})>{
    'dashboard (admin) — pending-review banner + recent-activity feed': (path: Paths.dashboard, prefs: adminPrefs),
    'dashboard (leader) — defaulter-alert "View" link': (path: Paths.dashboard, prefs: leaderPrefs),
    'dashboard (member) — "Pay Now" link': (path: Paths.dashboard, prefs: memberPrefs),
    'scheme eligibility — itemized criterion checks + badge': (path: Paths.schemeEligibility, prefs: memberPrefs),
    'meeting MOM (assigned/due line)': (path: Paths.meetingMom('mt1'), prefs: adminPrefs),
    'loans home (list)': (path: Paths.loans, prefs: adminPrefs),
    'savings home (list)': (path: Paths.savings, prefs: adminPrefs),
    'reports shg': (path: Paths.reportsShg, prefs: adminPrefs),
  };

  for (final locale in [const Locale('hi'), const Locale('te')]) {
    group('routes render without overflow at 2.0x text scale, locale=${locale.languageCode}', () {
      for (final entry in routes.entries) {
        testWidgets(entry.key, (tester) async {
          final router = await boot(tester, entry.value.prefs, locale);
          await goAndCheck(tester, router, entry.value.path, entry.key);
        });
      }
    });
  }
}
