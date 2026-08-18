import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import '../l10n/gen/app_localizations.dart';
import '../layout/app_shell.dart';
import '../models/types.dart';
import '../pages/admin/admin_audit_log_page.dart';
import '../pages/admin/admin_monitoring_page.dart';
import '../pages/admin/admin_schemes_page.dart';
import '../pages/admin/admin_training_courses_page.dart';
import '../pages/admin/admin_training_quiz_page.dart';
import '../pages/admin/admin_shgs_page.dart';
import '../pages/admin/admin_users_page.dart';
import '../pages/ai/ai_advisor_chat_page.dart';
import '../pages/ai/ai_hub_page.dart';
import '../pages/ai/ai_voice_assistant_page.dart';
import '../pages/analytics/analytics_dashboard_page.dart';
import '../pages/analytics/analytics_shg_detail_page.dart';
import '../pages/analytics/analytics_shg_list_page.dart';
import '../pages/auth/account_deactivated_page.dart';
import '../pages/auth/login_page.dart';
import '../pages/auth/otp_page.dart';
import '../pages/auth/profile_load_error_page.dart';
import '../pages/auth/profile_setup_page.dart';
import '../pages/auth/role_select_page.dart';
import '../pages/auth/shg_approval_pending_page.dart';
import '../pages/auth/splash_page.dart';
import '../pages/announcements/announcement_detail_page.dart';
import '../pages/announcements/announcements_home_page.dart';
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
import '../pages/marketplace/my_listings_page.dart';
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
import '../pages/profile/language_page.dart';
import '../pages/profile/profile_page.dart';
import '../pages/profile/settings_page.dart';
import '../pages/reports/attendance_report_page.dart';
import '../pages/reports/federation_growth_page.dart';
import '../pages/reports/federation_recovery_page.dart';
import '../pages/reports/federation_report_page.dart';
import '../pages/reports/federation_villages_page.dart';
import '../pages/reports/loan_statement_page.dart';
import '../pages/reports/member_report_page.dart';
import '../pages/reports/reports_hub_page.dart';
import '../pages/reports/shg_financial_summary_page.dart';
import '../pages/reports/shg_performance_report_page.dart';
import '../pages/reports/shg_report_page.dart';
import '../pages/savings/savings_entry_page.dart';
import '../pages/savings/savings_group_report_page.dart';
import '../pages/savings/savings_history_page.dart';
import '../pages/savings/savings_home_page.dart';
import '../pages/savings/savings_ledger_page.dart';
import '../pages/savings/savings_statement_page.dart';
import '../pages/schemes/scheme_applications_review_page.dart';
import '../pages/schemes/scheme_detail_page.dart';
import '../pages/schemes/scheme_eligibility_page.dart';
import '../pages/schemes/scheme_tracking_page.dart';
import '../pages/schemes/schemes_home_page.dart';
import '../pages/services/services_page.dart';
import '../pages/shg/member_detail_page.dart';
import '../pages/shg/shg_documents_page.dart';
import '../pages/shg/shg_home_page.dart';
import '../pages/shg/shg_join_requests_page.dart';
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
import '../services/supabase_service.dart';
import '../state/app_state.dart';
import '../widgets/error_screen.dart';
import 'navigation_history.dart';
import 'paths.dart';

const _leaderOrStaff = {Role.leader, Role.crp, Role.clf, Role.admin};
const _federationStaff = {Role.crp, Role.clf, Role.admin};

/// Screens the UI only ever links to from a leader/staff/admin-only nav
/// item, but which were previously reachable by ANY authenticated role via
/// direct URL — a member could open Loan Approvals, Admin > Manage Users,
/// etc. and see (and, for Loan Approvals, act on) data meant for other
/// roles. Checked by matchedLocation prefix since several of these are
/// section roots with their own sub-routes (e.g. every /app/admin/* page).
const _roleRestrictedPrefixes = <(String, Set<Role>)>[
  ('/app/loans/approval', _leaderOrStaff),
  ('/app/schemes/applications', _federationStaff),
  ('/app/savings/ledger', _leaderOrStaff),
  ('/app/meetings/schedule', _leaderOrStaff),
  ('/app/meetings/attendance', _leaderOrStaff),
  ('/app/shg/join-requests', {Role.leader}),
  // Leader-only, not `_leaderOrStaff` — round 138 found `ShgFinancialSummaryPage`/
  // `ShgPerformanceReportPage`/the Audit report all resolve "which SHG" from
  // `appState.profile?.shgId`, the viewer's own SHG only, with no parameter
  // to view a different one. Staff never have a `shg_id` of their own, so
  // this prefix letting them through led to three report pages rendering
  // permanently empty/zero with no explanation — closed the discoverable
  // path (the Reports Hub tile, `reports_hub_page.dart`) that same round,
  // but missed that this table independently allowed the same broken pages
  // via direct URL. Staff's genuinely-working per-SHG oversight is
  // `/app/analytics` below.
  ('/app/reports/shg', {Role.leader}),
  ('/app/reports/federation', _federationStaff),
  ('/app/analytics', _federationStaff),
  ('/app/admin', {Role.admin}),
  // Staff (crp/clf/admin), not leader — RLS (`training_courses_write_staff`/
  // `quiz_questions_write_staff`) already grants writes to `is_staff()`
  // specifically, matching `_federationStaff` here rather than
  // `_leaderOrStaff`. Deliberately not nested under `/app/admin` (see
  // `Paths.adminTrainingCourses`'s own doc comment) precisely so this
  // narrower rule — not the blanket admin-only one above — is what applies.
  ('/app/training/manage', _federationStaff),
  // Same reasoning, same fix shape as `/app/training/manage` just above:
  // `AdminMonitoringPage` moved out from under `/app/admin` specifically so
  // this narrower staff-only rule — not the blanket admin-only one above —
  // is what applies (see `Paths.adminMonitoring`'s own doc comment).
  (Paths.adminMonitoring, _federationStaff),
];

/// Split out of `buildRouter`'s `redirect:` parameter so the wrapper below
/// can record the SETTLED destination of every navigation into
/// [NavigationHistory] (see that class's own doc comment for why this
/// exists — the app's flat `context.go()` routing leaves Flutter's real
/// Navigator stack with nothing for `Navigator.canPop()` to act on, which
/// used to make every PageHeader Back button silently fall through to the
/// dashboard instead of the previous page). This function's own logic is
/// unchanged from before that split — every early `return` below is
/// exactly as it was when this lived inline as the `redirect:` closure.
String? _computeRedirect(BuildContext context, GoRouterState state, AppState appState) {
  // Segment-boundary match, not raw startsWith — the same fragility
      // the `_roleRestrictedPrefixes` loop below was hardened against
      // (round 188). Dormant today (no path collides), but this is the
      // single root boundary for "is this user inside the authenticated
      // app," so a future top-level auth-flow path starting with the
      // literal characters `app` (e.g. `/apply`, `/appeal`) would
      // otherwise silently satisfy the old check and mis-route a logged-
      // out/mid-onboarding user away from it.
      final onAuthFlow = state.matchedLocation != '/app' && !state.matchedLocation.startsWith('/app/');

      // No session yet (OTP not verified) — confined to the auth flow.
      if (!appState.hasSession) {
        if (onAuthFlow) return null;
        // Remember a genuine deep link so OtpPage can replay it after a
        // successful sign-in instead of always landing on the dashboard —
        // see AppState.capturePendingDeepLink and OtpPage._submit.
        // `state.topRoute` is only non-null when `state.matchedLocation`
        // actually resolved to a registered route (go_router's top-level
        // redirect state is built from the just-computed RouteMatchList,
        // whose match chain is empty for an unknown/malformed URL) — this
        // keeps a stray bad link from being captured and replayed later as
        // if it were a real destination.
        if (state.topRoute != null) appState.capturePendingDeepLink(state.matchedLocation);
        return Paths.splash;
      }

      // Session but no `profiles` row yet — either genuinely still
      // onboarding, or we simply couldn't check because the profile fetch
      // failed due to a network error (see
      // AppState.profileLoadFailedNetwork's doc comment). The latter must
      // NOT be routed to Profile Setup — to a returning, already-onboarded
      // offline user that would look exactly like the app forgot their
      // account and silently invite them to re-submit onboarding data.
      if (!appState.hasProfile) {
        if (appState.profileLoadFailedNetwork) {
          return state.matchedLocation == Paths.profileLoadError ? null : Paths.profileLoadError;
        }
        // `roleSelect` only belongs in this "still onboarding" set in demo
        // mode (see AppState.roleSelectReachableWithoutProfile) — in live
        // mode a direct URL visit to it here has no profile row for Role
        // Select to act on at all.
        final onboarding = state.matchedLocation == Paths.profileSetup ||
            (appState.roleSelectReachableWithoutProfile && state.matchedLocation == Paths.roleSelect);
        return onboarding ? null : Paths.profileSetup;
      }

      // Role Select serves no purpose in live mode once a profile row
      // exists — every signup starts as 'member' with a mandatory SHG join
      // request, and becoming 'leader' is now an approval-time decision
      // (see AppState.completeProfileSetup's and setRole's doc comments),
      // never a self-service one. Without this, an already-onboarded live
      // account could still navigate here directly and call setRole() to
      // reassign its own role at any time — the exact self-escalation gap
      // this whole redesign exists to close at signup, left wide open
      // post-signup otherwise (the `!hasProfile` block above only handles
      // the pre-profile case).
      if (SupabaseService.isConfigured && state.matchedLocation == Paths.roleSelect) {
        return Paths.dashboard;
      }

      // Admin deactivated this account (migration 0083) — the RLS layer
      // already silently rejects almost everything this account tries;
      // this stops it from continuing to navigate an app that no longer
      // works for it instead of explaining why. Checked before
      // needsShgApproval since that doesn't matter once the account itself
      // is deactivated.
      if (appState.accountDeactivated) {
        return state.matchedLocation == Paths.accountDeactivated ? null : Paths.accountDeactivated;
      }

      // Every signup's SHG join request hasn't been approved yet.
      // profileSetup stays reachable too, so a member can pick a different
      // SHG and submit a new request instead of being stuck — both while
      // still pending (ShgApprovalPendingPage's "Choose a different SHG" is
      // now offered there too, not just after rejection — see migration
      // 0033) and after rejection. ShgJoinRequestRepository.submit()
      // replaces any existing pending row instead of erroring on the
      // resubmit, so this is safe in both states.
      if (appState.needsShgApproval) {
        final allowed = state.matchedLocation == Paths.shgApprovalPending || state.matchedLocation == Paths.profileSetup;
        return allowed ? null : Paths.shgApprovalPending;
      }

      // Fully onboarded — keep out of the auth flow.
      if (onAuthFlow) return Paths.dashboard;

      // Fully onboarded but this screen is restricted to other roles.
      for (final (prefix, allowedRoles) in _roleRestrictedPrefixes) {
        // Segment-boundary match, not raw startsWith — a future route whose
        // path happens to share a restricted prefix as a string (e.g. a
        // hypothetical `/app/loans/approval-history` next to the restricted
        // `/app/loans/approval`) must not silently inherit its restriction.
        final matches = state.matchedLocation == prefix || state.matchedLocation.startsWith('$prefix/');
        if (matches && !allowedRoles.contains(appState.user.role)) {
          return Paths.dashboard;
        }
      }
  return null;
}

GoRouter buildRouter(AppState appState) {
  return GoRouter(
    initialLocation: Paths.splash,
    refreshListenable: appState,
    errorBuilder: (context, state) => AppErrorScreen(
      // Nullable, not `!` — see AppErrorScreen's own doc comment on why its
      // callers fall back to English instead of asserting non-null here.
      title: AppLocalizations.of(context)?.error404Title ?? 'Page not found',
      message: AppLocalizations.of(context)?.error404Message ?? "The page you're looking for doesn't exist or may have moved.",
      onRetry: () => context.go(Paths.dashboard),
    ),
    redirect: (context, state) {
      final result = _computeRedirect(context, state, appState);
      // Records the SETTLED destination (whatever this evaluation actually
      // resolves to), not `state.matchedLocation` unconditionally — a
      // non-null `result` means GoRouter will immediately re-invoke this
      // callback again for that new location anyway, so recording the
      // pre-redirect location here would add a transient auth-flow hop
      // (e.g. an expired-session bounce through `/login`) as its own Back
      // stop instead of just the page the user actually lands on.
      NavigationHistory.recordVisit(result ?? state.matchedLocation);
      return result;
    },
    routes: [
      GoRoute(path: Paths.splash, builder: (context, state) => const SplashPage()),
      GoRoute(path: Paths.login, builder: (context, state) => const LoginPage()),
      GoRoute(path: Paths.otp, builder: (context, state) => OtpPage(phone: state.extra as String?)),
      GoRoute(path: Paths.profileSetup, builder: (context, state) => const ProfileSetupPage()),
      GoRoute(path: Paths.roleSelect, builder: (context, state) => const RoleSelectPage()),
      GoRoute(path: Paths.shgApprovalPending, builder: (context, state) => const ShgApprovalPendingPage()),
      GoRoute(path: Paths.profileLoadError, builder: (context, state) => const ProfileLoadErrorPage()),
      GoRoute(path: Paths.accountDeactivated, builder: (context, state) => const AccountDeactivatedPage()),
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: Paths.dashboard, builder: (context, state) => const DashboardPage()),
          GoRoute(path: Paths.shg, builder: (context, state) => const ShgHomePage()),
          GoRoute(path: Paths.services, builder: (context, state) => const ServicesPage()),
          GoRoute(path: Paths.marketplace, builder: (context, state) => const MarketplaceHomePage()),
          GoRoute(path: Paths.profile, builder: (context, state) => const ProfilePage()),
          GoRoute(path: Paths.shgMembers, builder: (context, state) => const ShgMembersPage()),
          GoRoute(path: Paths.shgDocuments, builder: (context, state) => const ShgDocumentsPage()),
          GoRoute(path: Paths.shgJoinRequests, builder: (context, state) => const ShgJoinRequestsPage()),
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
          GoRoute(path: Paths.financialCashbook, builder: (context, state) => const FinancialLedgerPage(entryType: 'cashbook')),
          GoRoute(path: Paths.financialLedger, builder: (context, state) => const FinancialLedgerPage(entryType: 'ledger')),
          GoRoute(path: Paths.financialBank, builder: (context, state) => const FinancialLedgerPage(entryType: 'bank')),
          GoRoute(path: Paths.financialAudit, builder: (context, state) => const FinancialLedgerPage(entryType: 'audit')),
          GoRoute(path: Paths.livelihood, builder: (context, state) => const LivelihoodHomePage()),
          GoRoute(path: Paths.livelihoodEntry, builder: (context, state) => const LivelihoodEntryPage()),
          GoRoute(path: Paths.marketplaceAddProduct, builder: (context, state) => const AddProductPage()),
          GoRoute(path: Paths.marketplaceMyListings, builder: (context, state) => const MyListingsPage()),
          GoRoute(path: Paths.marketplaceOrders, builder: (context, state) => const MarketplaceOrdersPage()),
          GoRoute(path: Paths.marketplaceReviews, builder: (context, state) => const MarketplaceReviewsPage()),
          GoRoute(path: Paths.schemes, builder: (context, state) => const SchemesHomePage()),
          GoRoute(path: Paths.schemeApplications, builder: (context, state) => const SchemeApplicationsReviewPage()),
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
            // Title/hint were hardcoded English literals here regardless of
            // the app's language setting — reuses the same
            // `aiHubFinancialAdvisorTitle` key already shown on the AI hub
            // tile for the title, plus a new hint key per advisor type.
            builder: (context, state) => AiAdvisorChatPage(advisorType: 'financial', title: AppLocalizations.of(context)!.aiHubFinancialAdvisorTitle, hint: AppLocalizations.of(context)!.aiAdvisorChatFinancialHint),
          ),
          GoRoute(
            path: Paths.aiSchemeRecommender,
            builder: (context, state) => AiAdvisorChatPage(advisorType: 'scheme', title: AppLocalizations.of(context)!.aiHubSchemeRecommenderTitle, hint: AppLocalizations.of(context)!.aiAdvisorChatSchemeHint),
          ),
          GoRoute(
            path: Paths.aiMarketAdvisor,
            builder: (context, state) => AiAdvisorChatPage(advisorType: 'market', title: AppLocalizations.of(context)!.aiHubMarketAdvisorTitle, hint: AppLocalizations.of(context)!.aiAdvisorChatMarketHint),
          ),
          GoRoute(path: Paths.aiVoiceAssistant, builder: (context, state) => const AiVoiceAssistantPage()),
          GoRoute(path: Paths.reports, builder: (context, state) => const ReportsHubPage()),
          GoRoute(path: Paths.reportsMember, builder: (context, state) => const MemberReportPage()),
          GoRoute(path: Paths.reportsLoanStatement, builder: (context, state) => const LoanStatementPage()),
          GoRoute(path: Paths.reportsAttendance, builder: (context, state) => const AttendanceReportPage()),
          GoRoute(path: Paths.reportsShg, builder: (context, state) => const ShgReportPage()),
          GoRoute(path: Paths.reportsShgFinancialSummary, builder: (context, state) => const ShgFinancialSummaryPage()),
          GoRoute(path: Paths.reportsShgPerformance, builder: (context, state) => const ShgPerformanceReportPage()),
          GoRoute(path: Paths.reportsFederation, builder: (context, state) => const FederationReportPage()),
          GoRoute(path: Paths.reportsFederationVillages, builder: (context, state) => const FederationVillagesPage()),
          GoRoute(path: Paths.reportsFederationRecovery, builder: (context, state) => const FederationRecoveryPage()),
          GoRoute(path: Paths.reportsFederationGrowth, builder: (context, state) => const FederationGrowthPage()),
          GoRoute(path: Paths.analytics, builder: (context, state) => const AnalyticsDashboardPage()),
          GoRoute(path: Paths.analyticsShgList, builder: (context, state) => const AnalyticsShgListPage()),
          GoRoute(path: Paths.profileSettings, builder: (context, state) => const SettingsPage()),
          GoRoute(path: Paths.profileLanguage, builder: (context, state) => const LanguagePage()),
          GoRoute(path: Paths.adminUsers, builder: (context, state) => const AdminUsersPage()),
          GoRoute(path: Paths.adminSchemes, builder: (context, state) => const AdminSchemesPage()),
          GoRoute(path: Paths.adminMonitoring, builder: (context, state) => const AdminMonitoringPage()),
          GoRoute(path: Paths.adminAuditLog, builder: (context, state) => const AdminAuditLogPage()),
          GoRoute(path: Paths.adminShgs, builder: (context, state) => const AdminShgsPage()),
          GoRoute(path: Paths.adminTrainingCourses, builder: (context, state) => const AdminTrainingCoursesPage()),
          // Each of the routes below is keyed on its :id path parameter.
          // Without a ValueKey, go_router reuses the same Element when
          // navigating between two matches of the same route pattern (e.g.
          // one member's detail page to another's), so a page whose state
          // fetches data in initState (like AppAsyncBuilder) would keep
          // showing the first id's data after an in-app navigation.
          GoRoute(
            path: '/app/shg/members/:id',
            builder: (context, state) => MemberDetailPage(key: ValueKey(state.pathParameters['id']), memberId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/app/loans/:id',
            builder: (context, state) => LoanDetailPage(key: ValueKey(state.pathParameters['id']), loanId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/app/meetings/:id',
            builder: (context, state) => MeetingDetailPage(key: ValueKey(state.pathParameters['id']), meetingId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/app/meetings/:id/mom',
            builder: (context, state) => MeetingMomPage(key: ValueKey(state.pathParameters['id']), meetingId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/app/livelihood/:id',
            builder: (context, state) => LivelihoodDetailPage(key: ValueKey(state.pathParameters['id']), activityId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/app/marketplace/product/:id',
            builder: (context, state) => ProductDetailPage(key: ValueKey(state.pathParameters['id']), productId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/app/marketplace/edit-product/:id',
            builder: (context, state) => AddProductPage(key: ValueKey(state.pathParameters['id']), productId: state.pathParameters['id']),
          ),
          GoRoute(
            path: '/app/marketplace/orders/:id',
            builder: (context, state) => OrderDetailPage(key: ValueKey(state.pathParameters['id']), orderId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/app/schemes/:id',
            builder: (context, state) => SchemeDetailPage(key: ValueKey(state.pathParameters['id']), schemeId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/app/training/:id',
            builder: (context, state) => CourseDetailPage(key: ValueKey(state.pathParameters['id']), courseId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/app/training/:id/quiz',
            builder: (context, state) => CourseQuizPage(key: ValueKey(state.pathParameters['id']), courseId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/app/training/manage/:id/quiz',
            builder: (context, state) => AdminTrainingQuizPage(key: ValueKey(state.pathParameters['id']), courseId: state.pathParameters['id']!, courseTitle: state.extra as String?),
          ),
          GoRoute(
            path: '/app/announcements/:id',
            builder: (context, state) =>
                AnnouncementDetailPage(key: ValueKey(state.pathParameters['id']), announcementId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/app/support/ticket/:id',
            builder: (context, state) =>
                SupportTicketDetailPage(key: ValueKey(state.pathParameters['id']), ticketId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/app/analytics/shg/:id',
            builder: (context, state) => AnalyticsShgDetailPage(key: ValueKey(state.pathParameters['id']), shgId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/app/analytics/shg/:id/financial-summary',
            builder: (context, state) => ShgFinancialSummaryPage(key: ValueKey(state.pathParameters['id']), shgId: state.pathParameters['id']!, shgName: state.uri.queryParameters['name']),
          ),
          GoRoute(
            path: '/app/analytics/shg/:id/performance',
            builder: (context, state) => ShgPerformanceReportPage(key: ValueKey(state.pathParameters['id']), shgId: state.pathParameters['id']!, shgName: state.uri.queryParameters['name']),
          ),
          GoRoute(
            path: '/app/analytics/shg/:id/members',
            builder: (context, state) => ShgMembersPage(key: ValueKey(state.pathParameters['id']), shgId: state.pathParameters['id']!, shgName: state.uri.queryParameters['name']),
          ),
          GoRoute(
            path: '/app/analytics/shg/:id/join-requests',
            builder: (context, state) => ShgJoinRequestsPage(key: ValueKey(state.pathParameters['id']), shgId: state.pathParameters['id']!, shgName: state.uri.queryParameters['name']),
          ),
          GoRoute(path: Paths.allShgJoinRequests, builder: (context, state) => const ShgJoinRequestsPage(allShgs: true)),
        ],
      ),
    ],
  );
}
