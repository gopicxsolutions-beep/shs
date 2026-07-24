import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shg_saathi/data/loans.dart' as mock_loans;
import 'package:shg_saathi/data/marketplace.dart' as mock_marketplace;
import 'package:shg_saathi/data/members.dart' as mock_members;
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/dashboard/leader_dashboard.dart';
import 'package:shg_saathi/pages/dashboard/member_dashboard.dart';
import 'package:shg_saathi/repositories/admin_repository.dart';
import 'package:shg_saathi/repositories/loan_repository.dart';
import 'package:shg_saathi/repositories/marketplace_repository.dart';
import 'package:shg_saathi/repositories/meeting_repository.dart';
import 'package:shg_saathi/repositories/shg_repository.dart';
import 'package:shg_saathi/routes/paths.dart';
import 'package:shg_saathi/routes/router.dart';
import 'package:shg_saathi/state/app_state.dart';

/// This session has stress-tested VIEWPORT dimensions extensively —
/// `all_routes_smoke_test.dart` (400px width), `narrow_screen_stress_test.dart`
/// (320px width), `text_scale_stress_test.dart` (2.0x text scale) — but never
/// once stress-tested CONTENT length itself at a fixed, NORMAL viewport. A
/// single genuinely long real-world value (a descriptive multi-word SHG name,
/// a long member name, a loan purpose typed right up to its form's own
/// `maxLength`) can overflow a `Row` that assumed short content, completely
/// independent of screen width — a different failure mode from all three
/// prior dimensions.
///
/// Fixture values below are realistic, not artificially padded:
/// - `_longShgName` (57 chars) mirrors real, descriptive multi-word SHG
///   naming conventions used across Telangana/AP (e.g. "Sthree Shakthi"
///   federations) — well under `admin_shgs_page.dart`'s own 100-char
///   `maxLength` for the SHG name field.
/// - `_longMemberName` (37 chars) is a plausible full rural name (surname +
///   two given names), under `profile_page.dart`'s 100-char name field.
/// - `_longLoanPurpose` (199 chars) is deliberately AT `loan_apply_page.dart`'s
///   own 200-char `maxLength` — the realistic worst case a real member could
///   actually type and submit, not an arbitrary huge string beyond what the
///   form even allows.
/// - `_longProductName` (73 chars) is under `add_product_page.dart`'s
///   100-char name field.
/// - `_longProductDescription` (497 chars) is deliberately AT
///   `add_product_page.dart`'s own 500-char description `maxLength`, same
///   reasoning as the loan purpose above.
///
/// These are injected into demo mode's mock data via small, additive,
/// null-by-default test seams on the repositories (`debugShgNameOverride`,
/// `debugMembersOverride`, `debugLoansOverride`, `debugProductsOverride` —
/// see their doc comments in `lib/repositories/*.dart`), deliberately NOT by
/// editing the shared short values in `lib/data/*.dart` itself — every other
/// test in this suite keeps relying on those exact short values, and this
/// file resets every seam back to null in `tearDown` so it can never leak
/// into a test that runs after it even within this same file.
///
/// Reuses `all_routes_smoke_test.dart`'s exact boot harness (real `AppState`
/// + `GoRouter` + `Provider` + localization delegates, demo mode) and its
/// exact 400x900 "normal phone" viewport at the default 1.0x text scale —
/// deliberately NOT narrowed or text-scaled, so content length is the only
/// variable this file isolates — and the same 75-route full sweep (every
/// parameterless route the router registers), so the only thing that differs
/// from `all_routes_smoke_test.dart` is which values the demo mock data
/// hands to each page's widgets.
void main() {
  const longShgName = 'Sri Lakshmi Mahila Sthree Shakthi Swayam Sahayaka Sangham';
  const longMemberName = 'Komatireddy Venkata Lakshmi Narasamma';
  const longLoanPurpose =
      'Purchase of two additional milch buffaloes to expand the dairy business, plus cattle feed, veterinary care, and a small covered shed extension to protect the animals safely through the monsoon season';
  const longProductName = 'Handwoven Pochampally Ikat Cotton Saree with Temple Border and Zari Pallu';
  const longProductDescription =
      "Handwoven Pochampally Ikat cotton saree crafted on a traditional pit loom by our SHG's weaving collective, using natural vegetable dyes sourced from indigo, turmeric and madder root. Each saree takes nearly a week to complete, featuring the classic diamond ikat pattern along the body and a contrasting temple-border pallu with fine zari work. Comes with a matching unstitched blouse piece. Please allow 3-4 days for made-to-order pieces in specific color combinations; ready stock ships same day.";

  setUp(() {
    // One member (m6, "Chandrakala" — picked because, unlike m4 "Anasuya",
    // it isn't cross-referenced by a "must stay in sync" comment tying it to
    // a specific loans.dart row) gets the long name; every other field on
    // every other member is left byte-for-byte identical to the shared mock
    // list.
    final longMembers = mock_members.members
        .map((m) => m.id == 'm6'
            ? mock_members.Member(
                id: m.id,
                name: longMemberName,
                mobile: m.mobile,
                aadhaar: m.aadhaar,
                role: m.role,
                joiningDate: m.joiningDate,
                savings: m.savings,
                loanOutstanding: m.loanOutstanding,
                attendance: m.attendance,
                status: m.status,
              )
            : m)
        .toList();
    ShgRepository.debugMembersOverride = longMembers;
    AdminRepository.debugMembersOverride = longMembers;
    MeetingRepository.debugMembersOverride = longMembers;
    ShgRepository.debugShgNameOverride = longShgName;

    // l1 ("Lakshmi Devi") deliberately kept as memberName so this loan is
    // still the one demo mode resolves for the signed-in demo persona
    // (`defaultUser.name` == 'Lakshmi Devi') — that's what makes
    // member-scoped pages (LoanTrackingPage, LoanStatementPage,
    // MemberDashboard's "My Loan" card) resolve to THIS loan via
    // `fetchForMember`, not just the group-wide list pages.
    LoanRepository.debugLoansOverride = mock_loans.loans
        .map((l) => l.id == 'l1'
            ? mock_loans.Loan(
                id: l.id,
                memberName: l.memberName,
                purpose: longLoanPurpose,
                amount: l.amount,
                outstanding: l.outstanding,
                emi: l.emi,
                tenureMonths: l.tenureMonths,
                disbursedOn: l.disbursedOn,
                status: l.status,
                nextDueDate: l.nextDueDate,
              )
            : l)
        .toList();

    MarketplaceRepository.debugProductsOverride = mock_marketplace.marketplaceProducts
        .map((p) => p.id == 'p1'
            ? mock_marketplace.ProductMock(
                id: p.id,
                sellerName: p.sellerName,
                name: longProductName,
                description: longProductDescription,
                price: p.price,
                stock: p.stock,
                category: p.category,
              )
            : p)
        .toList();
  });

  tearDown(() {
    ShgRepository.debugShgNameOverride = null;
    ShgRepository.debugMembersOverride = null;
    AdminRepository.debugMembersOverride = null;
    MeetingRepository.debugMembersOverride = null;
    LoanRepository.debugLoansOverride = null;
    MarketplaceRepository.debugProductsOverride = null;
  });

  Future<GoRouter> boot(WidgetTester tester, Map<String, Object> prefs) async {
    // Same 400x900 "normal phone" canvas as all_routes_smoke_test.dart, at
    // the default 1.0x text scale — deliberately NOT narrowed or
    // text-scaled, so long CONTENT is the only variable under test here.
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
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> goAndCheck(WidgetTester tester, GoRouter router, String path, {Object? extra}) async {
    router.go(path, extra: extra);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Route $path threw during build/layout with long mock content');
  }

  group('unauthenticated auth-flow routes render without overflow with long content', () {
    testWidgets(Paths.splash, (tester) async {
      await boot(tester, const {});
      expect(tester.takeException(), isNull, reason: 'Route ${Paths.splash} threw during build/layout with long mock content');
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

  group('mid-onboarding routes render without overflow with long content', () {
    const prefs = {'shg_session_started': true};

    testWidgets(Paths.profileSetup, (tester) async {
      await boot(tester, prefs);
      expect(tester.takeException(), isNull, reason: 'Route ${Paths.profileSetup} threw during build/layout with long mock content');
    });

    testWidgets(Paths.roleSelect, (tester) async {
      final router = await boot(tester, prefs);
      await goAndCheck(tester, router, Paths.roleSelect);
    });
  });

  group('leader-only route renders without overflow with long content', () {
    const prefs = {'shg_session_started': true, 'shg_authenticated': true, 'shg_role': 'leader'};

    testWidgets(Paths.shgJoinRequests, (tester) async {
      final router = await boot(tester, prefs);
      await goAndCheck(tester, router, Paths.shgJoinRequests);
    });
  });

  group('admin-reachable /app routes render without overflow with long content', () {
    const prefs = {'shg_session_started': true, 'shg_authenticated': true, 'shg_role': 'admin'};

    for (final path in _adminAccessibleRoutes) {
      testWidgets(path, (tester) async {
        final router = await boot(tester, prefs);
        await goAndCheck(tester, router, path);
      });
    }
  });

  // `Paths.dashboard` branches internally on role (see dashboard_page.dart),
  // and the sweep above only ever reaches it as an admin — which renders
  // AdminDashboard, not MemberDashboard/LeaderDashboard. Both of those
  // specifically render `myLoan.purpose`/`l.purpose` (the long loan-purpose
  // fixture above), so they'd otherwise never get exercised by this file at
  // all. Pumped directly (same pattern as the existing
  // `test/pages/dashboards_test.dart`) rather than through the router, since
  // routing there requires a real member/leader profile this demo harness
  // doesn't set up.
  group('role-specific dashboards not reachable via the admin route sweep render without overflow with long content', () {
    Future<void> pumpDashboard(WidgetTester tester, Widget dashboard) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>(
          create: (_) => AppState(),
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: SingleChildScrollView(child: dashboard)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('MemberDashboard', (tester) async {
      await pumpDashboard(tester, const MemberDashboard());
      expect(tester.takeException(), isNull, reason: 'MemberDashboard threw during build/layout with long mock content');
    });

    testWidgets('LeaderDashboard', (tester) async {
      await pumpDashboard(tester, const LeaderDashboard());
      expect(tester.takeException(), isNull, reason: 'LeaderDashboard threw during build/layout with long mock content');
    });
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
