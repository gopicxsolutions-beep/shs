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

/// Regression coverage for the Government Schemes audit (round 101): the
/// staff-only applications review route (`_federationStaff` in
/// `router.dart`'s `_roleRestrictedPrefixes`) had no automated test at any
/// role, live or denied — the router logic itself was read and confirmed
/// correct, but nothing would have caught a future regression (e.g. a typo
/// in the restricted-prefix string, or the set of allowed roles silently
/// narrowing/widening). Mirrors `deep_link_redirect_test.dart`'s `boot()`
/// harness shape.
void main() {
  Future<GoRouter> boot(WidgetTester tester, AppState appState) async {
    SharedPreferences.setMockInitialValues({});
    await appState.init();
    final router = buildRouter(appState);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  String currentPath(GoRouter router) => router.routerDelegate.currentConfiguration.uri.toString();

  testWidgets('a member is redirected away from the staff-only scheme applications review route', (tester) async {
    final appState = AppState();
    final router = await boot(tester, appState);
    await appState.completeProfileSetup(name: 'Asha', village: 'Anantapur');
    await appState.setRole(Role.member);

    router.go(Paths.schemeApplications);
    await tester.pumpAndSettle();

    expect(currentPath(router), Paths.dashboard, reason: 'a plain member must never reach the staff review queue by direct navigation, even though the schemes hub never shows her a link to it');
  });

  testWidgets('a leader is also redirected — this route is federation-staff-only, not leader-or-staff', (tester) async {
    final appState = AppState();
    final router = await boot(tester, appState);
    await appState.completeProfileSetup(name: 'Lakshmi', village: 'Anantapur');
    await appState.setRole(Role.leader);

    router.go(Paths.schemeApplications);
    await tester.pumpAndSettle();

    expect(currentPath(router), Paths.dashboard, reason: 'unlike SHG-tier reports, the scheme review queue is platform-wide and staff-only — a leader deciding her own SHG\'s scheme applications is not part of the design (staff review the whole platform\'s queue)');
  });

  testWidgets('a crp (federation staff) reaches the review route', (tester) async {
    final appState = AppState();
    final router = await boot(tester, appState);
    await appState.completeProfileSetup(name: 'Ravi', village: 'Anantapur');
    await appState.setRole(Role.crp);

    router.go(Paths.schemeApplications);
    await tester.pumpAndSettle();

    expect(currentPath(router), Paths.schemeApplications, reason: 'crp is in _federationStaff and must actually reach the page it is allowed to see');
  });
}
