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

/// Round 26 (`all_routes_smoke_test.dart`) proved WIDTH overflow bugs at a
/// 400-logical-pixel-wide phone viewport; round 27 (`text_scale_stress_test.dart`)
/// swept TEXT SCALE at that same 400px width. Neither has ever exercised a
/// genuinely NARROW screen at normal (1.0x) text scale — a different failure
/// mode from both: fixed-width `Row`s/tight paddings that fit comfortably at
/// 400px (or that only broke once text was scaled up) can still overflow
/// horizontally at a real budget-Android width. 320 logical pixels is not a
/// theoretical edge case — it's the width of Android Go devices and older/
/// cheaper phones that are still in active daily use among this app's actual
/// target users (rural Indian women, frequently on budget hardware).
///
/// This file reuses `all_routes_smoke_test.dart`'s exact boot harness (real
/// `AppState` + `GoRouter` + `Provider` + localization delegates, demo mode)
/// and its exact route list — every *parameterless* route the router
/// registers, across the same four groups (unauthenticated auth-flow,
/// mid-onboarding, leader-only, and the 69 admin-reachable `/app/*` routes)
/// — changing only the test viewport to 320x900 at the default 1.0x text
/// scale, and asserts each route renders without throwing (which is how
/// `RenderFlex overflowed` layout errors surface in these tests, per round
/// 26/27's own methodology).
void main() {
  Future<GoRouter> boot(WidgetTester tester, Map<String, Object> prefs) async {
    // 320 logical px: a real, common budget-Android width (Android Go
    // devices, older/cheaper phones), not a theoretical edge case. Height
    // kept tall (900) so this test isolates the WIDTH axis specifically,
    // same as how text_scale_stress_test.dart isolates the text-scale axis
    // by keeping width fixed.
    tester.view.physicalSize = const Size(320, 900);
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
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> goAndCheck(WidgetTester tester, GoRouter router, String path, {Object? extra}) async {
    router.go(path, extra: extra);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Route $path threw during build/layout at 320px width');
  }

  group('unauthenticated auth-flow routes render without overflow at 320px width', () {
    testWidgets(Paths.splash, (tester) async {
      await boot(tester, const {});
      expect(tester.takeException(), isNull, reason: 'Route ${Paths.splash} threw during build/layout at 320px width');
    });

    testWidgets(Paths.login, (tester) async {
      final router = await boot(tester, const {});
      await goAndCheck(tester, router, Paths.login);
    });

    testWidgets(Paths.otp, (tester) async {
      final router = await boot(tester, const {});
      await goAndCheck(tester, router, Paths.otp, extra: '9876543210');
    });
  });

  group('mid-onboarding routes render without overflow at 320px width', () {
    const prefs = {'shg_session_started': true};

    testWidgets(Paths.profileSetup, (tester) async {
      await boot(tester, prefs);
      expect(tester.takeException(), isNull, reason: 'Route ${Paths.profileSetup} threw during build/layout at 320px width');
    });

    testWidgets(Paths.roleSelect, (tester) async {
      final router = await boot(tester, prefs);
      await goAndCheck(tester, router, Paths.roleSelect);
    });
  });

  group('leader-only route renders without overflow at 320px width', () {
    const prefs = {'shg_session_started': true, 'shg_authenticated': true, 'shg_role': 'leader'};

    testWidgets(Paths.shgJoinRequests, (tester) async {
      final router = await boot(tester, prefs);
      await goAndCheck(tester, router, Paths.shgJoinRequests);
    });
  });

  group('admin-reachable /app routes render without overflow at 320px width', () {
    const prefs = {'shg_session_started': true, 'shg_authenticated': true, 'shg_role': 'admin'};

    for (final path in _adminAccessibleRoutes) {
      testWidgets(path, (tester) async {
        final router = await boot(tester, prefs);
        await goAndCheck(tester, router, path);
      });
    }
  });
}

const _adminAccessibleRoutes = <String>[
  Paths.dashboard,
  Paths.shg,
  Paths.services,
  Paths.marketplace,
  Paths.profile,
  Paths.shgMembers,
  Paths.shgDocuments,
  Paths.savings,
  Paths.savingsEntry,
  Paths.savingsHistory,
  Paths.savingsLedger,
  Paths.savingsStatement,
  Paths.savingsGroupReport,
  Paths.loans,
  Paths.loanApply,
  Paths.loanApproval,
  Paths.loanTracking,
  Paths.meetings,
  Paths.meetingSchedule,
  Paths.meetingAttendance,
  Paths.meetingQr,
  Paths.financialCashbook,
  Paths.financialLedger,
  Paths.financialBank,
  Paths.financialAudit,
  Paths.livelihood,
  Paths.livelihoodEntry,
  Paths.marketplaceAddProduct,
  Paths.marketplaceOrders,
  Paths.marketplaceReviews,
  Paths.schemes,
  Paths.schemeApplications,
  Paths.schemeEligibility,
  Paths.schemeTracking,
  Paths.training,
  Paths.trainingCertificates,
  Paths.payments,
  Paths.paymentsQr,
  Paths.paymentsHistory,
  Paths.announcements,
  Paths.support,
  Paths.supportChat,
  Paths.supportVoice,
  Paths.supportFaq,
  Paths.supportTicket,
  Paths.aiHub,
  Paths.aiFinancialAdvisor,
  Paths.aiSchemeRecommender,
  Paths.aiMarketAdvisor,
  Paths.aiVoiceAssistant,
  Paths.reports,
  Paths.reportsMember,
  Paths.reportsLoanStatement,
  Paths.reportsAttendance,
  Paths.reportsShg,
  Paths.reportsShgFinancialSummary,
  Paths.reportsShgPerformance,
  Paths.reportsFederation,
  Paths.reportsFederationVillages,
  Paths.reportsFederationRecovery,
  Paths.reportsFederationGrowth,
  Paths.analytics,
  Paths.analyticsShgList,
  Paths.profileSettings,
  Paths.profileLanguage,
  Paths.adminUsers,
  Paths.adminSchemes,
  Paths.adminMonitoring,
  Paths.adminShgs,
];
