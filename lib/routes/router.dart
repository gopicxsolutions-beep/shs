import 'package:go_router/go_router.dart';
import '../layout/app_shell.dart';
import '../pages/ai/ai_advisor_chat_page.dart';
import '../pages/ai/ai_hub_page.dart';
import '../pages/analytics/analytics_dashboard_page.dart';
import '../pages/analytics/analytics_shg_detail_page.dart';
import '../pages/analytics/analytics_shg_list_page.dart';
import '../pages/auth/login_page.dart';
import '../pages/auth/otp_page.dart';
import '../pages/auth/profile_setup_page.dart';
import '../pages/auth/role_select_page.dart';
import '../pages/auth/splash_page.dart';
import '../pages/announcements/announcement_detail_page.dart';
import '../pages/announcements/announcements_home_page.dart';
import '../pages/common/coming_soon.dart';
import '../pages/dashboard/dashboard_page.dart';
import '../pages/financial/financial_ledger_page.dart';
import '../pages/livelihood/livelihood_detail_page.dart';
import '../pages/livelihood/livelihood_entry_page.dart';
import '../pages/livelihood/livelihood_home_page.dart';
import '../pages/loans/loan_apply_page.dart';
import '../pages/loans/loan_approval_page.dart';
import '../pages/loans/loan_detail_page.dart';
import '../pages/loans/loan_tracking_page.dart';
import '../pages/loans/loans_home_page.dart';
import '../pages/marketplace/add_product_page.dart';
import '../pages/marketplace/marketplace_home_page.dart';
import '../pages/marketplace/marketplace_orders_page.dart';
import '../pages/marketplace/marketplace_reviews_page.dart';
import '../pages/marketplace/order_detail_page.dart';
import '../pages/marketplace/product_detail_page.dart';
import '../pages/meetings/meeting_attendance_page.dart';
import '../pages/meetings/meeting_detail_page.dart';
import '../pages/meetings/meeting_mom_page.dart';
import '../pages/meetings/meeting_qr_page.dart';
import '../pages/meetings/meeting_schedule_page.dart';
import '../pages/meetings/meetings_home_page.dart';
import '../pages/payments/payments_home_page.dart';
import '../pages/payments/payments_history_page.dart';
import '../pages/payments/payments_qr_page.dart';
import '../pages/reports/federation_report_page.dart';
import '../pages/reports/member_report_page.dart';
import '../pages/reports/reports_hub_page.dart';
import '../pages/reports/shg_report_page.dart';
import '../pages/savings/savings_entry_page.dart';
import '../pages/savings/savings_group_report_page.dart';
import '../pages/savings/savings_history_page.dart';
import '../pages/savings/savings_home_page.dart';
import '../pages/savings/savings_ledger_page.dart';
import '../pages/savings/savings_statement_page.dart';
import '../pages/schemes/scheme_detail_page.dart';
import '../pages/schemes/scheme_eligibility_page.dart';
import '../pages/schemes/scheme_tracking_page.dart';
import '../pages/schemes/schemes_home_page.dart';
import '../pages/shg/member_detail_page.dart';
import '../pages/shg/shg_documents_page.dart';
import '../pages/shg/shg_home_page.dart';
import '../pages/shg/shg_members_page.dart';
import '../pages/support/support_chat_page.dart';
import '../pages/support/support_faq_page.dart';
import '../pages/support/support_home_page.dart';
import '../pages/support/support_ticket_detail_page.dart';
import '../pages/support/support_ticket_form_page.dart';
import '../pages/support/support_voice_page.dart';
import '../pages/training/certificates_page.dart';
import '../pages/training/course_detail_page.dart';
import '../pages/training/course_quiz_page.dart';
import '../pages/training/training_home_page.dart';
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
          GoRoute(path: Paths.marketplace, builder: (context, state) => const MarketplaceHomePage()),
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
          GoRoute(path: Paths.financialCashbook, builder: (context, state) => const FinancialLedgerPage(entryType: 'cashbook', title: 'Cashbook')),
          GoRoute(path: Paths.financialLedger, builder: (context, state) => const FinancialLedgerPage(entryType: 'ledger', title: 'General Ledger')),
          GoRoute(path: Paths.financialBank, builder: (context, state) => const FinancialLedgerPage(entryType: 'bank', title: 'Bank Reconciliation')),
          GoRoute(path: Paths.financialAudit, builder: (context, state) => const FinancialLedgerPage(entryType: 'audit', title: 'Audit Trail')),
          GoRoute(path: Paths.livelihood, builder: (context, state) => const LivelihoodHomePage()),
          GoRoute(path: Paths.livelihoodEntry, builder: (context, state) => const LivelihoodEntryPage()),
          GoRoute(path: Paths.marketplaceAddProduct, builder: (context, state) => const AddProductPage()),
          GoRoute(path: Paths.marketplaceOrders, builder: (context, state) => const MarketplaceOrdersPage()),
          GoRoute(path: Paths.marketplaceReviews, builder: (context, state) => const MarketplaceReviewsPage()),
          GoRoute(path: Paths.schemes, builder: (context, state) => const SchemesHomePage()),
          GoRoute(path: Paths.schemeEligibility, builder: (context, state) => const SchemeEligibilityPage()),
          GoRoute(path: Paths.schemeTracking, builder: (context, state) => const SchemeTrackingPage()),
          GoRoute(path: Paths.training, builder: (context, state) => const TrainingHomePage()),
          GoRoute(path: Paths.trainingCertificates, builder: (context, state) => const CertificatesPage()),
          GoRoute(path: Paths.payments, builder: (context, state) => const PaymentsHomePage()),
          GoRoute(path: Paths.paymentsQr, builder: (context, state) => const PaymentsQrPage()),
          GoRoute(path: Paths.paymentsHistory, builder: (context, state) => const PaymentsHistoryPage()),
          GoRoute(path: Paths.announcements, builder: (context, state) => const AnnouncementsHomePage()),
          GoRoute(path: Paths.support, builder: (context, state) => const SupportHomePage()),
          GoRoute(path: Paths.supportChat, builder: (context, state) => const SupportChatPage()),
          GoRoute(path: Paths.supportVoice, builder: (context, state) => const SupportVoicePage()),
          GoRoute(path: Paths.supportFaq, builder: (context, state) => const SupportFaqPage()),
          GoRoute(path: Paths.supportTicket, builder: (context, state) => const SupportTicketFormPage()),
          GoRoute(path: Paths.aiHub, builder: (context, state) => const AiHubPage()),
          GoRoute(
            path: Paths.aiFinancialAdvisor,
            builder: (context, state) => const AiAdvisorChatPage(advisorType: 'financial', title: 'Financial Advisor', hint: 'Ask about savings, loans, or budgeting for your SHG.'),
          ),
          GoRoute(
            path: Paths.aiSchemeRecommender,
            builder: (context, state) => const AiAdvisorChatPage(advisorType: 'scheme', title: 'Scheme Recommender', hint: 'Ask which government schemes you may be eligible for.'),
          ),
          GoRoute(
            path: Paths.aiMarketAdvisor,
            builder: (context, state) => const AiAdvisorChatPage(advisorType: 'market', title: 'Market Advisor', hint: 'Ask about pricing, demand, or selling your products.'),
          ),
          GoRoute(path: Paths.reports, builder: (context, state) => const ReportsHubPage()),
          GoRoute(path: Paths.reportsMember, builder: (context, state) => const MemberReportPage()),
          GoRoute(path: Paths.reportsShg, builder: (context, state) => const ShgReportPage()),
          GoRoute(path: Paths.reportsFederation, builder: (context, state) => const FederationReportPage()),
          GoRoute(path: Paths.analytics, builder: (context, state) => const AnalyticsDashboardPage()),
          GoRoute(path: Paths.analyticsShgList, builder: (context, state) => const AnalyticsShgListPage()),
          comingSoon(Paths.profileSettings, 'Settings'),
          comingSoon(Paths.profileLanguage, 'Language'),
          comingSoon(Paths.adminUsers, 'Manage Users'),
          comingSoon(Paths.adminSchemes, 'Manage Schemes'),
          comingSoon(Paths.adminMonitoring, 'System Monitoring'),
          GoRoute(path: '/app/shg/members/:id', builder: (context, state) => MemberDetailPage(memberId: state.pathParameters['id']!)),
          GoRoute(path: '/app/loans/:id', builder: (context, state) => LoanDetailPage(loanId: state.pathParameters['id']!)),
          GoRoute(path: '/app/meetings/:id', builder: (context, state) => MeetingDetailPage(meetingId: state.pathParameters['id']!)),
          GoRoute(path: '/app/meetings/:id/mom', builder: (context, state) => MeetingMomPage(meetingId: state.pathParameters['id']!)),
          GoRoute(path: '/app/livelihood/:id', builder: (context, state) => LivelihoodDetailPage(activityId: state.pathParameters['id']!)),
          GoRoute(path: '/app/marketplace/product/:id', builder: (context, state) => ProductDetailPage(productId: state.pathParameters['id']!)),
          GoRoute(path: '/app/marketplace/orders/:id', builder: (context, state) => OrderDetailPage(orderId: state.pathParameters['id']!)),
          GoRoute(path: '/app/schemes/:id', builder: (context, state) => SchemeDetailPage(schemeId: state.pathParameters['id']!)),
          GoRoute(path: '/app/training/:id', builder: (context, state) => CourseDetailPage(courseId: state.pathParameters['id']!)),
          GoRoute(path: '/app/training/:id/quiz', builder: (context, state) => CourseQuizPage(courseId: state.pathParameters['id']!)),
          GoRoute(path: '/app/announcements/:id', builder: (context, state) => AnnouncementDetailPage(announcementId: state.pathParameters['id']!)),
          GoRoute(path: '/app/support/ticket/:id', builder: (context, state) => SupportTicketDetailPage(ticketId: state.pathParameters['id']!)),
          GoRoute(path: '/app/analytics/shg/:id', builder: (context, state) => AnalyticsShgDetailPage(shgId: state.pathParameters['id']!)),
        ],
      ),
    ],
  );
}
