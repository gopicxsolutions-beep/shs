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

/// Regression coverage for gap-hunt iteration 36: `AdminMonitoringPage` used
/// to live at `/app/admin/monitoring`, nested under the blanket
/// `('/app/admin', {Role.admin})` `_roleRestrictedPrefixes` rule — silently
/// blocking crp/clf even though `infra_health_checks_select_staff` (RLS) and
/// `system-health-check`'s own `authorizeCaller()` both already grant them
/// read access. Moved to its own `/app/monitoring` prefix with a narrower
/// `_federationStaff` rule (same fix shape as `adminTrainingCourses`).
/// Mirrors `scheme_applications_role_gate_test.dart`'s `boot()` harness.
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

  testWidgets('a member is redirected away from the platform monitoring route', (tester) async {
    final appState = AppState();
    final router = await boot(tester, appState);
    await appState.completeProfileSetup(name: 'Asha', village: 'Anantapur');
    await appState.setRole(Role.member);

    router.go(Paths.adminMonitoring);
    await tester.pumpAndSettle();

    expect(currentPath(router), Paths.dashboard);
  });

  testWidgets('a leader is also redirected — this route is federation-staff-only, not leader-or-staff', (tester) async {
    final appState = AppState();
    final router = await boot(tester, appState);
    await appState.completeProfileSetup(name: 'Lakshmi', village: 'Anantapur');
    await appState.setRole(Role.leader);

    router.go(Paths.adminMonitoring);
    await tester.pumpAndSettle();

    expect(currentPath(router), Paths.dashboard);
  });

  for (final staffRole in [Role.crp, Role.clf, Role.admin]) {
    testWidgets('a $staffRole (federation staff) reaches the monitoring route', (tester) async {
      final appState = AppState();
      final router = await boot(tester, appState);
      await appState.completeProfileSetup(name: 'Ravi', village: 'Anantapur');
      await appState.setRole(staffRole);

      router.go(Paths.adminMonitoring);
      await tester.pumpAndSettle();

      expect(currentPath(router), Paths.adminMonitoring, reason: '$staffRole is in _federationStaff and RLS/the edge function already grant it read access — the router must not block it');
    });
  }
}
