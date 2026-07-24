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

/// Round 76 (`narrow_screen_stress_test.dart`) swept WIDTH alone (320px at
/// the default 1.0x text scale) and round 27 (`text_scale_stress_test.dart`)
/// swept TEXT SCALE alone (1.5x/2.0x at a comfortable 400px width). Neither
/// has ever combined both stresses at once, even though their co-occurrence
/// is a completely ordinary, plausible device state for this app's actual
/// users: a budget Android phone (narrow physical width) with the OS
/// accessibility text-scale setting turned up (common for older users with
/// vision difficulty — exactly this app's likely demographic in places).
/// `Flexible`/`Expanded` + `TextOverflow.ellipsis` fixes tuned against only
/// one axis at a time can still overflow once both axes are stressed
/// together — less horizontal room to give AND larger glyphs demanding more
/// of it simultaneously.
///
/// This file reuses `narrow_screen_stress_test.dart`'s exact boot harness
/// and full 75-route list (itself reused from `all_routes_smoke_test.dart`),
/// changing only the viewport to match round 76 (320x900 logical pixels)
/// while additionally wrapping the routed content in a `MediaQuery` override
/// forcing `TextScaler.linear(2.0)`, the same mechanism
/// `text_scale_stress_test.dart` uses to simulate a device-wide
/// accessibility text-size setting.
void main() {
  Future<GoRouter> boot(WidgetTester tester, Map<String, Object> prefs) async {
    // 320 logical px: the same real budget-Android width round 76 used.
    // Height kept tall (900) so this test isolates width + text scale
    // without also being squeezed vertically.
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
          // Simulates an OS/browser-level accessibility text-scale setting
          // on top of the narrow viewport above — same mechanism
          // text_scale_stress_test.dart uses to override just textScaler.
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

  Future<void> goAndCheck(WidgetTester tester, GoRouter router, String path, {Object? extra}) async {
    router.go(path, extra: extra);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Route $path threw during build/layout at 320px width + 2.0x text scale');
  }

  group('unauthenticated auth-flow routes render without overflow at 320px width + 2.0x text scale', () {
    testWidgets(Paths.splash, (tester) async {
      await boot(tester, const {});
      expect(tester.takeException(), isNull, reason: 'Route ${Paths.splash} threw during build/layout at 320px width + 2.0x text scale');
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

  group('mid-onboarding routes render without overflow at 320px width + 2.0x text scale', () {
    const prefs = {'shg_session_started': true};

    testWidgets(Paths.profileSetup, (tester) async {
      await boot(tester, prefs);
      expect(tester.takeException(), isNull, reason: 'Route ${Paths.profileSetup} threw during build/layout at 320px width + 2.0x text scale');
    });

    testWidgets(Paths.roleSelect, (tester) async {
      final router = await boot(tester, prefs);
      await goAndCheck(tester, router, Paths.roleSelect);
    });
  });

  group('leader-only route renders without overflow at 320px width + 2.0x text scale', () {
    const prefs = {'shg_session_started': true, 'shg_authenticated': true, 'shg_role': 'leader'};

    testWidgets(Paths.shgJoinRequests, (tester) async {
      final router = await boot(tester, prefs);
      await goAndCheck(tester, router, Paths.shgJoinRequests);
    });
  });

  group('admin-reachable /app routes render without overflow at 320px width + 2.0x text scale', () {
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
