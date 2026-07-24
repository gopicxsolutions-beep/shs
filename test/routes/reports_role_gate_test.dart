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

/// Regression coverage for the Reports audit (round 102): `router.dart`'s
/// `_roleRestrictedPrefixes` correctly gates every SHG-tier and
/// Federation-tier report page (each sub-report's path shares its tier's
/// prefix, e.g. `/app/reports/shg/performance` starts with
/// `/app/reports/shg`) — read and confirmed correct, but nothing
/// automated actually exercised a denied role hitting these routes
/// directly, despite Reports having the most role tiers of any module
/// (member/leader/CRP-CLF-Admin). Mirrors
/// `scheme_applications_role_gate_test.dart`'s harness (round 101, same
/// audit series).
void main() {
  Future<GoRouter> boot(WidgetTester tester, AppState appState, Role role) async {
    SharedPreferences.setMockInitialValues({});
    await appState.init();
    await appState.completeProfileSetup(name: 'Asha', village: 'Anantapur');
    await appState.setRole(role);
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

  group('member-tier report routes are open to every role', () {
    for (final role in Role.values) {
      testWidgets('${role.name} reaches the personal report hub', (tester) async {
        final router = await boot(tester, AppState(), role);
        router.go(Paths.reportsMember);
        await tester.pumpAndSettle();
        expect(currentPath(router), Paths.reportsMember);
      });
    }
  });

  group('SHG-tier report routes (/app/reports/shg*) are leader-or-staff only', () {
    testWidgets('a member is redirected away from the SHG reports hub', (tester) async {
      final router = await boot(tester, AppState(), Role.member);
      router.go(Paths.reportsShg);
      await tester.pumpAndSettle();
      expect(currentPath(router), Paths.dashboard);
    });

    testWidgets('a member is redirected away from a specific SHG sub-report reached by direct URL, not just the hub', (tester) async {
      final router = await boot(tester, AppState(), Role.member);
      router.go(Paths.reportsShgPerformance);
      await tester.pumpAndSettle();
      expect(currentPath(router), Paths.dashboard, reason: 'the sub-report path must inherit the /app/reports/shg prefix gate even when navigated to directly, not only when reached via the hub');
    });

    testWidgets('a leader reaches the SHG reports hub', (tester) async {
      final router = await boot(tester, AppState(), Role.leader);
      router.go(Paths.reportsShg);
      await tester.pumpAndSettle();
      expect(currentPath(router), Paths.reportsShg);
    });
  });

  group('Federation-tier report routes (/app/reports/federation*) are CRP/CLF/Admin only', () {
    testWidgets('a member is redirected away from the federation reports hub', (tester) async {
      final router = await boot(tester, AppState(), Role.member);
      router.go(Paths.reportsFederation);
      await tester.pumpAndSettle();
      expect(currentPath(router), Paths.dashboard);
    });

    testWidgets('a leader is also redirected — federation reports are staff-only, not leader-or-staff', (tester) async {
      final router = await boot(tester, AppState(), Role.leader);
      router.go(Paths.reportsFederation);
      await tester.pumpAndSettle();
      expect(currentPath(router), Paths.dashboard);
    });

    testWidgets('a member is redirected away from a specific federation sub-report reached by direct URL', (tester) async {
      final router = await boot(tester, AppState(), Role.member);
      router.go(Paths.reportsFederationGrowth);
      await tester.pumpAndSettle();
      expect(currentPath(router), Paths.dashboard);
    });

    testWidgets('a crp reaches the federation reports hub', (tester) async {
      final router = await boot(tester, AppState(), Role.crp);
      router.go(Paths.reportsFederation);
      await tester.pumpAndSettle();
      expect(currentPath(router), Paths.reportsFederation, reason: 'FR-RPT-4 includes CRP, not just CLF/Admin — see this round\'s SRS.md fix');
    });
  });
}
