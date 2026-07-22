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

/// Rounds 26/27/76/77 all stressed this app's layout at a tall PORTRAIT
/// viewport — narrow WIDTH alone (round 76, 320x900), large TEXT SCALE alone
/// (rounds 26-27, 400x900-ish), and both combined (round 77,
/// `narrow_screen_large_text_stress_test.dart`, 320x900). Every one of those
/// kept height generously tall (900px) specifically so it isolated its own
/// axis without also being squeezed vertically. None has ever tested
/// LANDSCAPE orientation — a real, reachable device state (a user rotates
/// their phone, plausible while using the camera-based QR scanner or filling
/// in a wide form) where height shrinks dramatically while width grows. This
/// is a genuinely different failure mode from all four prior rounds:
/// portrait-oriented tests stress horizontal space; landscape stresses
/// VERTICAL space, which no prior round of this session specifically tested.
/// A rigid `Column` (dashboard stat cards, a big icon + title + subtitle +
/// form stacked on an onboarding screen, a fixed-height calendar-date badge)
/// that comfortably fit portrait's abundant height can overflow vertically
/// once that height drops to ~360px, even though its *width* was never in
/// question.
///
/// This file reuses `narrow_screen_stress_test.dart`'s exact boot harness
/// and full 75-route list (itself reused from `all_routes_smoke_test.dart`),
/// changing only the viewport to 800x360 logical pixels — a realistic
/// landscape dimension for a common ~6" phone (the same physical device as
/// round 76's 320x900 portrait phone, rotated) — at the default 1.0x text
/// scale, isolating the landscape-orientation axis on its own.
void main() {
  Future<GoRouter> boot(WidgetTester tester, Map<String, Object> prefs) async {
    // 800x360 logical px: a realistic landscape phone viewport (a common
    // ~6" phone rotated from portrait), the mirror image of round 76's
    // 320x900 portrait test. Width is generous here so this test isolates
    // the shrunken-HEIGHT axis specifically, same as how
    // narrow_screen_stress_test.dart isolates the width axis by keeping
    // height tall.
    tester.view.physicalSize = const Size(800, 360);
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
    expect(tester.takeException(), isNull, reason: 'Route $path threw during build/layout at 800x360 landscape viewport');
  }

  group('unauthenticated auth-flow routes render without overflow at 800x360 landscape viewport', () {
    testWidgets(Paths.splash, (tester) async {
      await boot(tester, const {});
      expect(tester.takeException(), isNull, reason: 'Route ${Paths.splash} threw during build/layout at 800x360 landscape viewport');
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

  group('mid-onboarding routes render without overflow at 800x360 landscape viewport', () {
    const prefs = {'shg_session_started': true};

    testWidgets(Paths.profileSetup, (tester) async {
      await boot(tester, prefs);
      expect(tester.takeException(), isNull, reason: 'Route ${Paths.profileSetup} threw during build/layout at 800x360 landscape viewport');
    });

    testWidgets(Paths.roleSelect, (tester) async {
      final router = await boot(tester, prefs);
      await goAndCheck(tester, router, Paths.roleSelect);
    });
  });

  group('leader-only route renders without overflow at 800x360 landscape viewport', () {
    const prefs = {'shg_session_started': true, 'shg_authenticated': true, 'shg_role': 'leader'};

    testWidgets(Paths.shgJoinRequests, (tester) async {
      final router = await boot(tester, prefs);
      await goAndCheck(tester, router, Paths.shgJoinRequests);
    });
  });

  group('admin-reachable /app routes render without overflow at 800x360 landscape viewport', () {
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
