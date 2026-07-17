import 'package:go_router/go_router.dart';
import '../layout/app_shell.dart';
import '../pages/auth/login_page.dart';
import '../pages/auth/otp_page.dart';
import '../pages/auth/profile_setup_page.dart';
import '../pages/auth/role_select_page.dart';
import '../pages/auth/splash_page.dart';
import '../pages/common/coming_soon.dart';
import '../pages/dashboard/dashboard_page.dart';
import '../state/app_state.dart';
import 'paths.dart';

GoRouter buildRouter(AppState appState) {
  GoRoute comingSoon(String path, String title) => GoRoute(path: path, builder: (context, state) => ComingSoonPage(title: title));

  return GoRouter(
    initialLocation: Paths.splash,
    refreshListenable: appState,
    redirect: (context, state) {
      final loggedIn = appState.isAuthenticated;
      final onAuthFlow = !state.matchedLocation.startsWith('/app');
      if (!loggedIn && !onAuthFlow) return Paths.splash;
      if (loggedIn && onAuthFlow) return Paths.dashboard;
      return null;
    },
    routes: [
      GoRoute(path: Paths.splash, builder: (context, state) => const SplashPage()),
      GoRoute(path: Paths.login, builder: (context, state) => const LoginPage()),
      GoRoute(path: Paths.otp, builder: (context, state) => const OtpPage()),
      GoRoute(path: Paths.profileSetup, builder: (context, state) => const ProfileSetupPage()),
      GoRoute(path: Paths.roleSelect, builder: (context, state) => const RoleSelectPage()),
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: Paths.dashboard, builder: (context, state) => const DashboardPage()),
          comingSoon(Paths.shg, 'My SHG'),
          comingSoon(Paths.services, 'Services'),
          comingSoon(Paths.marketplace, 'Marketplace'),
          comingSoon(Paths.profile, 'Profile'),
          comingSoon(Paths.shgMembers, 'Members'),
          comingSoon(Paths.shgDocuments, 'Documents'),
          comingSoon(Paths.savings, 'Savings'),
          comingSoon(Paths.savingsEntry, 'Add Savings'),
          comingSoon(Paths.savingsHistory, 'Savings History'),
          comingSoon(Paths.savingsLedger, 'Savings Ledger'),
          comingSoon(Paths.savingsStatement, 'Savings Statement'),
          comingSoon(Paths.savingsGroupReport, 'Group Savings Report'),
          comingSoon(Paths.loans, 'Loans'),
          comingSoon(Paths.loanApply, 'Apply for Loan'),
          comingSoon(Paths.loanApproval, 'Loan Approvals'),
          comingSoon(Paths.loanTracking, 'Loan Tracking'),
          comingSoon(Paths.meetings, 'Meetings'),
          comingSoon(Paths.meetingSchedule, 'Schedule Meeting'),
          comingSoon(Paths.meetingAttendance, 'Attendance'),
          comingSoon(Paths.meetingQr, 'QR Attendance'),
          comingSoon(Paths.financialCashbook, 'Cashbook'),
          comingSoon(Paths.financialLedger, 'General Ledger'),
          comingSoon(Paths.financialBank, 'Bank Reconciliation'),
          comingSoon(Paths.financialAudit, 'Audit Trail'),
          comingSoon(Paths.livelihood, 'Livelihoods'),
          comingSoon(Paths.livelihoodEntry, 'Add Activity'),
          comingSoon(Paths.marketplaceAddProduct, 'Add Product'),
          comingSoon(Paths.marketplaceOrders, 'Orders'),
          comingSoon(Paths.marketplaceReviews, 'Reviews'),
          comingSoon(Paths.schemes, 'Government Schemes'),
          comingSoon(Paths.schemeEligibility, 'Eligibility Checker'),
          comingSoon(Paths.schemeTracking, 'Application Tracking'),
          comingSoon(Paths.training, 'Training'),
          comingSoon(Paths.trainingCertificates, 'Certificates'),
          comingSoon(Paths.payments, 'Digital Payments'),
          comingSoon(Paths.paymentsQr, 'Scan & Pay'),
          comingSoon(Paths.paymentsHistory, 'Payment History'),
          comingSoon(Paths.announcements, 'Announcements'),
          comingSoon(Paths.support, 'Support'),
          comingSoon(Paths.supportChat, 'Chat Support'),
          comingSoon(Paths.supportVoice, 'Voice Support'),
          comingSoon(Paths.supportFaq, 'FAQs'),
          comingSoon(Paths.supportTicket, 'Raise a Ticket'),
          comingSoon(Paths.aiHub, 'AI Advisors'),
          comingSoon(Paths.aiFinancialAdvisor, 'AI Financial Advisor'),
          comingSoon(Paths.aiSchemeRecommender, 'AI Scheme Recommender'),
          comingSoon(Paths.aiMarketAdvisor, 'AI Market Advisor'),
          comingSoon(Paths.reports, 'Reports'),
          comingSoon(Paths.reportsMember, 'My Reports'),
          comingSoon(Paths.reportsShg, 'SHG Reports'),
          comingSoon(Paths.reportsFederation, 'Federation Reports'),
          comingSoon(Paths.analytics, 'Analytics'),
          comingSoon(Paths.analyticsShgList, 'SHGs Monitoring'),
          comingSoon(Paths.profileSettings, 'Settings'),
          comingSoon(Paths.profileLanguage, 'Language'),
          comingSoon(Paths.adminUsers, 'Manage Users'),
          comingSoon(Paths.adminSchemes, 'Manage Schemes'),
          comingSoon(Paths.adminMonitoring, 'System Monitoring'),
          GoRoute(path: '/app/shg/members/:id', builder: (context, state) => ComingSoonPage(title: 'Member Detail')),
          GoRoute(path: '/app/loans/:id', builder: (context, state) => ComingSoonPage(title: 'Loan Detail')),
          GoRoute(path: '/app/meetings/:id', builder: (context, state) => ComingSoonPage(title: 'Meeting Detail')),
          GoRoute(path: '/app/meetings/:id/mom', builder: (context, state) => ComingSoonPage(title: 'Minutes of Meeting')),
          GoRoute(path: '/app/livelihood/:id', builder: (context, state) => ComingSoonPage(title: 'Activity Detail')),
          GoRoute(path: '/app/marketplace/product/:id', builder: (context, state) => ComingSoonPage(title: 'Product Detail')),
          GoRoute(path: '/app/marketplace/orders/:id', builder: (context, state) => ComingSoonPage(title: 'Order Detail')),
          GoRoute(path: '/app/schemes/:id', builder: (context, state) => ComingSoonPage(title: 'Scheme Detail')),
          GoRoute(path: '/app/training/:id', builder: (context, state) => ComingSoonPage(title: 'Course Detail')),
          GoRoute(path: '/app/training/:id/quiz', builder: (context, state) => ComingSoonPage(title: 'Course Quiz')),
          GoRoute(path: '/app/announcements/:id', builder: (context, state) => ComingSoonPage(title: 'Announcement')),
          GoRoute(path: '/app/analytics/shg/:id', builder: (context, state) => ComingSoonPage(title: 'SHG Analytics')),
        ],
      ),
    ],
  );
}
