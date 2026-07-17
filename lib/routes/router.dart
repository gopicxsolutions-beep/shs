import 'package:go_router/go_router.dart';
import '../layout/app_shell.dart';
import '../pages/auth/login_page.dart';
import '../pages/auth/otp_page.dart';
import '../pages/auth/profile_setup_page.dart';
import '../pages/auth/role_select_page.dart';
import '../pages/auth/splash_page.dart';
import '../pages/common/coming_soon.dart';
import '../pages/dashboard/dashboard_page.dart';
import '../pages/loans/loan_apply_page.dart';
import '../pages/loans/loan_approval_page.dart';
import '../pages/loans/loan_detail_page.dart';
import '../pages/loans/loan_tracking_page.dart';
import '../pages/loans/loans_home_page.dart';
import '../pages/meetings/meeting_attendance_page.dart';
import '../pages/meetings/meeting_detail_page.dart';
import '../pages/meetings/meeting_mom_page.dart';
import '../pages/meetings/meeting_qr_page.dart';
import '../pages/meetings/meeting_schedule_page.dart';
import '../pages/meetings/meetings_home_page.dart';
import '../pages/savings/savings_entry_page.dart';
import '../pages/savings/savings_group_report_page.dart';
import '../pages/savings/savings_history_page.dart';
import '../pages/savings/savings_home_page.dart';
import '../pages/savings/savings_ledger_page.dart';
import '../pages/savings/savings_statement_page.dart';
import '../pages/shg/member_detail_page.dart';
import '../pages/shg/shg_documents_page.dart';
import '../pages/shg/shg_home_page.dart';
import '../pages/shg/shg_members_page.dart';
import '../state/app_state.dart';
import 'paths.dart';

GoRouter buildRouter(AppState appState) {
  GoRoute comingSoon(String path, String title) => GoRoute(path: path, builder: (context, state) => ComingSoonPage(title: title));

  return GoRouter(
    initialLocation: Paths.splash,
    refreshListenable: appState,
    redirect: (context, state) {
      final onAuthFlow = !state.matchedLocation.startsWith('/app');

      // No session yet (OTP not verified) — confined to the auth flow.
      if (!appState.hasSession) return onAuthFlow ? null : Paths.splash;

      // Session but no `profiles` row yet — must finish onboarding.
      if (!appState.hasProfile) {
        final onboarding = state.matchedLocation == Paths.profileSetup || state.matchedLocation == Paths.roleSelect;
        return onboarding ? null : Paths.profileSetup;
      }

      // Fully onboarded — keep out of the auth flow.
      if (onAuthFlow) return Paths.dashboard;
      return null;
    },
    routes: [
      GoRoute(path: Paths.splash, builder: (context, state) => const SplashPage()),
      GoRoute(path: Paths.login, builder: (context, state) => const LoginPage()),
      GoRoute(path: Paths.otp, builder: (context, state) => OtpPage(phone: state.extra as String?)),
      GoRoute(path: Paths.profileSetup, builder: (context, state) => const ProfileSetupPage()),
      GoRoute(path: Paths.roleSelect, builder: (context, state) => const RoleSelectPage()),
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: Paths.dashboard, builder: (context, state) => const DashboardPage()),
          GoRoute(path: Paths.shg, builder: (context, state) => const ShgHomePage()),
          comingSoon(Paths.services, 'Services'),
          comingSoon(Paths.marketplace, 'Marketplace'),
          comingSoon(Paths.profile, 'Profile'),
          GoRoute(path: Paths.shgMembers, builder: (context, state) => const ShgMembersPage()),
          GoRoute(path: Paths.shgDocuments, builder: (context, state) => const ShgDocumentsPage()),
          GoRoute(path: Paths.savings, builder: (context, state) => const SavingsHomePage()),
          GoRoute(path: Paths.savingsEntry, builder: (context, state) => const SavingsEntryPage()),
          GoRoute(path: Paths.savingsHistory, builder: (context, state) => const SavingsHistoryPage()),
          GoRoute(path: Paths.savingsLedger, builder: (context, state) => const SavingsLedgerPage()),
          GoRoute(path: Paths.savingsStatement, builder: (context, state) => const SavingsStatementPage()),
          GoRoute(path: Paths.savingsGroupReport, builder: (context, state) => const SavingsGroupReportPage()),
          GoRoute(path: Paths.loans, builder: (context, state) => const LoansHomePage()),
          GoRoute(path: Paths.loanApply, builder: (context, state) => const LoanApplyPage()),
          GoRoute(path: Paths.loanApproval, builder: (context, state) => const LoanApprovalPage()),
          GoRoute(path: Paths.loanTracking, builder: (context, state) => const LoanTrackingPage()),
          GoRoute(path: Paths.meetings, builder: (context, state) => const MeetingsHomePage()),
          GoRoute(path: Paths.meetingSchedule, builder: (context, state) => const MeetingSchedulePage()),
          GoRoute(path: Paths.meetingAttendance, builder: (context, state) => const MeetingAttendancePage()),
          GoRoute(path: Paths.meetingQr, builder: (context, state) => const MeetingQrPage()),
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
          GoRoute(path: '/app/shg/members/:id', builder: (context, state) => MemberDetailPage(memberId: state.pathParameters['id']!)),
          GoRoute(path: '/app/loans/:id', builder: (context, state) => LoanDetailPage(loanId: state.pathParameters['id']!)),
          GoRoute(path: '/app/meetings/:id', builder: (context, state) => MeetingDetailPage(meetingId: state.pathParameters['id']!)),
          GoRoute(path: '/app/meetings/:id/mom', builder: (context, state) => MeetingMomPage(meetingId: state.pathParameters['id']!)),
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
