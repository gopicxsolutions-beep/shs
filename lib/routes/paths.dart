class Paths {
  static const splash = '/';
  static const login = '/login';
  static const otp = '/otp';
  static const profileSetup = '/profile-setup';
  static const roleSelect = '/role-select';
  static const shgApprovalPending = '/shg-approval-pending';
  static const profileLoadError = '/profile-load-error';
  static const accountDeactivated = '/account-deactivated';

  static const dashboard = '/app/dashboard';
  static const shg = '/app/shg';
  static const services = '/app/services';
  static const marketplace = '/app/marketplace';
  static const profile = '/app/profile';

  static const shgMembers = '/app/shg/members';
  static const shgDocuments = '/app/shg/documents';
  static const shgJoinRequests = '/app/shg/join-requests';
  static String shgMember(String id) => '/app/shg/members/$id';

  static const savings = '/app/savings';
  static const savingsEntry = '/app/savings/entry';
  static const savingsHistory = '/app/savings/history';
  static const savingsLedger = '/app/savings/ledger';
  static const savingsStatement = '/app/savings/statement';
  static const savingsGroupReport = '/app/savings/group-report';

  static const loans = '/app/loans';
  static const loanApply = '/app/loans/apply';
  static const loanApproval = '/app/loans/approval';
  static const loanTracking = '/app/loans/tracking';
  static String loanDetail(String id) => '/app/loans/$id';

  static const meetings = '/app/meetings';
  static const meetingSchedule = '/app/meetings/schedule';
  static const meetingAttendance = '/app/meetings/attendance';
  static const meetingQr = '/app/meetings/qr-attendance';
  static String meetingDetail(String id) => '/app/meetings/$id';
  static String meetingMom(String id) => '/app/meetings/$id/mom';

  static const financialCashbook = '/app/financial/cashbook';
  static const financialLedger = '/app/financial/ledger';
  static const financialBank = '/app/financial/bank';
  static const financialAudit = '/app/financial/audit';

  static const livelihood = '/app/livelihood';
  static const livelihoodEntry = '/app/livelihood/entry';
  static String livelihoodDetail(String id) => '/app/livelihood/$id';

  static String marketplaceProduct(String id) => '/app/marketplace/product/$id';
  static const marketplaceAddProduct = '/app/marketplace/add-product';
  static const marketplaceOrders = '/app/marketplace/orders';
  static String marketplaceOrderDetail(String id) => '/app/marketplace/orders/$id';
  static const marketplaceReviews = '/app/marketplace/reviews';

  static const schemes = '/app/schemes';
  static String schemeDetail(String id) => '/app/schemes/$id';
  static const schemeEligibility = '/app/schemes/eligibility';
  static const schemeTracking = '/app/schemes/tracking';
  static const schemeApplications = '/app/schemes/applications';

  static const training = '/app/training';
  static String trainingDetail(String id) => '/app/training/$id';
  static String trainingQuiz(String id) => '/app/training/$id/quiz';
  static const trainingCertificates = '/app/training/certificates';

  static const payments = '/app/payments';
  static const paymentsQr = '/app/payments/qr';
  static const paymentsHistory = '/app/payments/history';

  static const announcements = '/app/announcements';
  static String announcementDetail(String id) => '/app/announcements/$id';

  static const support = '/app/support';
  static const supportChat = '/app/support/chat';
  static const supportVoice = '/app/support/voice';
  static const supportFaq = '/app/support/faq';
  static const supportTicket = '/app/support/ticket';
  static String supportTicketDetail(String id) => '/app/support/ticket/$id';

  static const aiHub = '/app/ai';
  static const aiFinancialAdvisor = '/app/ai/financial-advisor';
  static const aiSchemeRecommender = '/app/ai/scheme-recommender';
  static const aiMarketAdvisor = '/app/ai/market-advisor';
  static const aiVoiceAssistant = '/app/ai/voice-assistant';

  static const reports = '/app/reports';
  static const reportsMember = '/app/reports/member';
  static const reportsLoanStatement = '/app/reports/member/loan-statement';
  static const reportsAttendance = '/app/reports/member/attendance';
  static const reportsShg = '/app/reports/shg';
  static const reportsShgFinancialSummary = '/app/reports/shg/financial-summary';
  static const reportsShgPerformance = '/app/reports/shg/performance';
  static const reportsFederation = '/app/reports/federation';
  static const reportsFederationVillages = '/app/reports/federation/villages';
  static const reportsFederationRecovery = '/app/reports/federation/recovery';
  static const reportsFederationGrowth = '/app/reports/federation/growth';

  static const analytics = '/app/analytics';
  static const analyticsShgList = '/app/analytics/shgs';
  static String analyticsShgDetail(String id) => '/app/analytics/shg/$id';
  // FR-RPT-2 (docs/SRS.md): lets crp/clf/admin reach a *specific* SHG's
  // Financial Summary/Performance Report from its Analytics detail page —
  // nested under `/app/analytics` so the existing staff-only router
  // restriction on that prefix covers these too, no new _roleRestrictedPrefixes
  // entry needed.
  static String analyticsShgFinancialSummary(String id, {String? name}) =>
      Uri(path: '/app/analytics/shg/$id/financial-summary', queryParameters: name == null ? null : {'name': name}).toString();
  static String analyticsShgPerformance(String id, {String? name}) =>
      Uri(path: '/app/analytics/shg/$id/performance', queryParameters: name == null ? null : {'name': name}).toString();
  static String analyticsShgMembers(String id, {String? name}) =>
      Uri(path: '/app/analytics/shg/$id/members', queryParameters: name == null ? null : {'name': name}).toString();
  static String analyticsShgJoinRequests(String id, {String? name}) =>
      Uri(path: '/app/analytics/shg/$id/join-requests', queryParameters: name == null ? null : {'name': name}).toString();
  // Federation-wide "every SHG's pending join requests in one list" —
  // reached from the crp/clf/admin dashboard shortcut, since staff have no
  // `shg_id` of their own for the per-SHG override route above to resolve
  // to without first picking a specific SHG. Nested under `/app/analytics`
  // for the same reason as its siblings above: the existing staff-only
  // router restriction on that prefix covers this too, no new
  // `_roleRestrictedPrefixes` entry needed.
  static const allShgJoinRequests = '/app/analytics/join-requests';

  static const profileSettings = '/app/profile/settings';
  static const profileLanguage = '/app/profile/language';

  static const adminUsers = '/app/admin/users';
  static const adminSchemes = '/app/admin/schemes';
  // Deliberately NOT under `/app/admin/...`, for the same reason as
  // `adminTrainingCourses` below: RLS (`infra_health_checks_select_staff`)
  // and the `system-health-check` edge function's own `authorizeCaller()`
  // both already grant crp/clf (not just admin) read access to this data —
  // `/app/admin`'s blanket admin-only restriction was silently overriding
  // that grant at the router layer, leaving crp/clf with no monitoring
  // surface at all despite being explicitly provisioned for one
  // (gap-hunt iteration 36).
  static const adminMonitoring = '/app/monitoring';
  static const adminAuditLog = '/app/admin/audit-log';
  static const adminShgs = '/app/admin/shgs';
  // Deliberately NOT under `/app/admin/...`: RLS already permits crp/clf
  // (not just admin) to write training content (`training_courses_write_staff`/
  // `quiz_questions_write_staff`, both `is_staff()`), and `/app/admin` is
  // blanket-restricted to `Role.admin` by `_roleRestrictedPrefixes` in
  // router.dart — nesting here would make the router redirect crp/clf away
  // before this page's own isStaff-gated UI ever renders. Sits under
  // `/app/training/...` instead, with its own narrower staff-only
  // `_roleRestrictedPrefixes` entry (mirrors `shgJoinRequests`'s
  // narrower-than-its-neighbors override).
  static const adminTrainingCourses = '/app/training/manage';
  static String adminTrainingQuiz(String courseId) => '/app/training/manage/$courseId/quiz';
}
