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

/// Round 26 (`test/routes/all_routes_smoke_test.dart`) proved that pumping
/// every route at a real phone WIDTH surfaces genuine `RenderFlex` overflow
/// bugs invisible at desktop width. This file applies the same
/// systematic-test methodology to a different, equally real axis: TEXT
/// SCALE. A visually-impaired or older user commonly sets their OS
/// accessibility text size to 130-200%; Flutter's `MediaQuery.textScaler`
/// propagates that app-wide. `Flexible`/`Expanded` + `TextOverflow.ellipsis`
/// (round 26's fix) handles WIDTH overflow but does not by itself prevent
/// HEIGHT-based clipping: a `Row` with `CrossAxisAlignment.center` inside a
/// fixed-height `Container`/`SizedBox`, or a fixed-height button/badge, can
/// still look broken once its text scales up.
///
/// Rather than re-pumping all 75 routes (already proven not to throw at
/// 1.0x), this sweeps a representative subset — one instance of every
/// distinct page *shape* in the app (every role's dashboard, list pages,
/// `:id` detail pages, forms, and a dialog) — at `TextScaler.linear(1.5)`
/// and `TextScaler.linear(2.0)`, reusing the exact same boot harness
/// (`AppState` + real `GoRouter` + `Provider` + localization delegates,
/// phone-sized surface) as `all_routes_smoke_test.dart`. The detail-page
/// entries use real mock ids from `lib/data/*.dart` (`l1`, `mt1`, `m1`) so
/// the pages render their actual content instead of a not-found guard.
void main() {
  Future<GoRouter> boot(WidgetTester tester, Map<String, Object> prefs, TextScaler textScaler) async {
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
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          // Simulates an OS/browser-level accessibility text-scale setting:
          // wraps the routed content in a MediaQuery that overrides just
          // textScaler, same as how a real device propagates the user's
          // system text-size preference app-wide.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> goAndCheck(WidgetTester tester, GoRouter router, String path) async {
    router.go(path);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Route $path threw during build/layout');
  }

  const adminPrefs = {'shg_session_started': true, 'shg_authenticated': true, 'shg_role': 'admin'};
  const leaderPrefs = {'shg_session_started': true, 'shg_authenticated': true, 'shg_role': 'leader'};
  const memberPrefs = {'shg_session_started': true, 'shg_authenticated': true, 'shg_role': 'member'};
  const clfPrefs = {'shg_session_started': true, 'shg_authenticated': true, 'shg_role': 'clf'};

  // One instance of every distinct page shape: 4 role dashboards, list
  // pages, 3 `:id` detail pages (real mock ids), form pages, and misc
  // text-heavy pages (FAQ, admin users with role badges, announcements).
  final routes = <String, ({String path, Map<String, Object> prefs})>{
    'dashboard (member)': (path: Paths.dashboard, prefs: memberPrefs),
    'dashboard (leader)': (path: Paths.dashboard, prefs: leaderPrefs),
    'dashboard (CLF)': (path: Paths.dashboard, prefs: clfPrefs),
    'dashboard (admin)': (path: Paths.dashboard, prefs: adminPrefs),
    'shg home': (path: Paths.shg, prefs: adminPrefs),
    'savings home (list)': (path: Paths.savings, prefs: adminPrefs),
    'loans home (list)': (path: Paths.loans, prefs: adminPrefs),
    'loan detail': (path: Paths.loanDetail('l1'), prefs: adminPrefs),
    'meeting detail': (path: Paths.meetingDetail('mt1'), prefs: adminPrefs),
    'shg member detail': (path: Paths.shgMember('m1'), prefs: adminPrefs),
    'loan apply (form)': (path: Paths.loanApply, prefs: adminPrefs),
    'meeting schedule (form)': (path: Paths.meetingSchedule, prefs: adminPrefs),
    'marketplace add product (form)': (path: Paths.marketplaceAddProduct, prefs: adminPrefs),
    'financial cashbook': (path: Paths.financialCashbook, prefs: adminPrefs),
    'profile settings': (path: Paths.profileSettings, prefs: adminPrefs),
    'admin users (role badges)': (path: Paths.adminUsers, prefs: adminPrefs),
    'reports shg': (path: Paths.reportsShg, prefs: adminPrefs),
    'ai financial advisor (chat)': (path: Paths.aiFinancialAdvisor, prefs: adminPrefs),
    'support faq': (path: Paths.supportFaq, prefs: adminPrefs),
    'announcements home (list)': (path: Paths.announcements, prefs: adminPrefs),
  };

  for (final scale in [1.5, 2.0]) {
    final textScaler = TextScaler.linear(scale);
    group('routes render without overflow at ${scale}x text scale', () {
      for (final entry in routes.entries) {
        testWidgets(entry.key, (tester) async {
          final router = await boot(tester, entry.value.prefs, textScaler);
          await goAndCheck(tester, router, entry.value.path);
        });
      }
    });
  }

  group('financial entry dialog renders without overflow at scaled text', () {
    for (final scale in [1.5, 2.0]) {
      testWidgets('${scale}x', (tester) async {
        final router = await boot(tester, adminPrefs, TextScaler.linear(scale));
        await goAndCheck(tester, router, Paths.financialCashbook);

        // Open financial_entry_dialog.dart's AlertDialog the same way a
        // real admin would — tap the "Add entry" icon button in the
        // PageHeader.
        await tester.tap(find.byTooltip('Add entry'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Financial entry dialog threw during build/layout at ${scale}x');
        expect(find.text('Add entry'), findsWidgets);
      });
    }
  });
}
