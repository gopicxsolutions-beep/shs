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

/// This session has now tested every PAIRWISE combination of three layout
/// stress dimensions: narrow 320px width alone (round 76), width + 2.0x text
/// scale (round 77), realistic long content alone at a normal viewport
/// (round 77), width + long content (round 78), and landscape orientation
/// alone (round 78). The one combination never tried: ALL THREE at once —
/// narrow 320px width, 2.0x text scale, AND realistic long content,
/// simultaneously. This is the highest-stress combination attempted yet: a
/// `Flexible`/ellipsis fix tuned against any one or two of these axes is not
/// guaranteed to survive all three together — genuinely long text has to be
/// both truncated in far less horizontal room AND rendered with glyphs twice
/// the normal size in that same shrunken space, while any fixed-size sibling
/// (an icon, a badge, a leading avatar) in the same `Row` also has to share
/// that same doubly-squeezed width.
///
/// Reuses round 77's exact 320x900 + `MediaQuery(textScaler:
/// TextScaler.linear(2.0))` boot harness
/// (`narrow_screen_large_text_stress_test.dart`) together with round 77/78's
/// exact long-content fixture values and debug override seams verbatim
/// (`long_content_stress_test.dart`'s `_longShgName`, `_longMemberName`,
/// `_longLoanPurpose`, `_longProductName`, `_longProductDescription`, and the
/// same `debugShgNameOverride`/`debugMembersOverride`/`debugLoansOverride`/
/// `debugProductsOverride` seams on `ShgRepository`/`AdminRepository`/
/// `MeetingRepository`/`LoanRepository`/`MarketplaceRepository`), across the
/// same 75-route full sweep plus the 2 role-specific dashboards unreachable
/// via the standard admin route sweep.
void main() {
  const longShgName = 'Sri Lakshmi Mahila Sthree Shakthi Swayam Sahayaka Sangham';
  const longMemberName = 'Komatireddy Venkata Lakshmi Narasamma';
  const longLoanPurpose =
      'Purchase of two additional milch buffaloes to expand the dairy business, plus cattle feed, veterinary care, and a small covered shed extension to protect the animals safely through the monsoon season';
  const longProductName = 'Handwoven Pochampally Ikat Cotton Saree with Temple Border and Zari Pallu';
  const longProductDescription =
      "Handwoven Pochampally Ikat cotton saree crafted on a traditional pit loom by our SHG's weaving collective, using natural vegetable dyes sourced from indigo, turmeric and madder root. Each saree takes nearly a week to complete, featuring the classic diamond ikat pattern along the body and a contrasting temple-border pallu with fine zari work. Comes with a matching unstitched blouse piece. Please allow 3-4 days for made-to-order pieces in specific color combinations; ready stock ships same day.";

  setUp(() {
    // Same single-member override as long_content_stress_test.dart (m6,
    // "Chandrakala" — not cross-referenced by loans.dart) gets the long
    // name; every other field on every other member left untouched.
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

    // l1 ("Lakshmi Devi") kept as memberName so this loan is still the one
    // demo mode resolves for the signed-in demo persona, same as
    // long_content_stress_test.dart.
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
    // 320 logical px, same real budget-Android width as round 76/77's
    // narrow-width harnesses. Height kept tall (900) so this test isolates
    // width + text scale + content length without also being squeezed
    // vertically.
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
          // on top of the narrow viewport and long mock content above —
          // same mechanism narrow_screen_large_text_stress_test.dart uses.
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
    expect(tester.takeException(), isNull,
        reason: 'Route $path threw during build/layout at 320px width + 2.0x text scale + long mock content');
  }

  group('unauthenticated auth-flow routes render without overflow at 320px width + 2.0x text scale + long content', () {
    testWidgets(Paths.splash, (tester) async {
      await boot(tester, const {});
      expect(tester.takeException(), isNull,
          reason: 'Route ${Paths.splash} threw during build/layout at 320px width + 2.0x text scale + long mock content');
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

  group('mid-onboarding routes render without overflow at 320px width + 2.0x text scale + long content', () {
    const prefs = {'shg_session_started': true};

    testWidgets(Paths.profileSetup, (tester) async {
      await boot(tester, prefs);
      expect(tester.takeException(), isNull,
          reason: 'Route ${Paths.profileSetup} threw during build/layout at 320px width + 2.0x text scale + long mock content');
    });

    testWidgets(Paths.roleSelect, (tester) async {
      final router = await boot(tester, prefs);
      await goAndCheck(tester, router, Paths.roleSelect);
    });
  });

  group('leader-only route renders without overflow at 320px width + 2.0x text scale + long content', () {
    const prefs = {'shg_session_started': true, 'shg_authenticated': true, 'shg_role': 'leader'};

    testWidgets(Paths.shgJoinRequests, (tester) async {
      final router = await boot(tester, prefs);
      await goAndCheck(tester, router, Paths.shgJoinRequests);
    });
  });

  group('admin-reachable /app routes render without overflow at 320px width + 2.0x text scale + long content', () {
    const prefs = {'shg_session_started': true, 'shg_authenticated': true, 'shg_role': 'admin'};

    for (final path in _adminAccessibleRoutes) {
      testWidgets(path, (tester) async {
        final router = await boot(tester, prefs);
        await goAndCheck(tester, router, path);
      });
    }
  });

  // Same rationale as long_content_stress_test.dart/
  // narrow_screen_long_content_stress_test.dart: `Paths.dashboard` only ever
  // reaches AdminDashboard through the sweep above, so the
  // long-purpose-rendering MemberDashboard/LeaderDashboard branches need to
  // be pumped directly, now at the narrow 320px width + 2.0x text scale too.
  group(
      'role-specific dashboards not reachable via the admin route sweep render without overflow at 320px width + 2.0x text scale + long content',
      () {
    Future<void> pumpDashboard(WidgetTester tester, Widget dashboard) async {
      tester.view.physicalSize = const Size(320, 900);
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
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2.0)),
              child: child!,
            ),
            home: Scaffold(body: SingleChildScrollView(child: dashboard)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('MemberDashboard', (tester) async {
      await pumpDashboard(tester, const MemberDashboard());
      expect(tester.takeException(), isNull,
          reason: 'MemberDashboard threw during build/layout at 320px width + 2.0x text scale + long mock content');
    });

    testWidgets('LeaderDashboard', (tester) async {
      await pumpDashboard(tester, const LeaderDashboard());
      expect(tester.takeException(), isNull,
          reason: 'LeaderDashboard threw during build/layout at 320px width + 2.0x text scale + long mock content');
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
