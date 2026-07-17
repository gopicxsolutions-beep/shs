class Paths {
  static const splash = '/';
  static const login = '/login';
  static const otp = '/otp';
  static const profileSetup = '/profile-setup';
  static const roleSelect = '/role-select';
  static const shgApprovalPending = '/shg-approval-pending';

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

  static const reports = '/app/reports';
  static const reportsMember = '/app/reports/member';
  static const reportsShg = '/app/reports/shg';
  static const reportsFederation = '/app/reports/federation';

  static const analytics = '/app/analytics';
  static const analyticsShgList = '/app/analytics/shgs';
  static String analyticsShgDetail(String id) => '/app/analytics/shg/$id';

  static const profileSettings = '/app/profile/settings';
  static const profileLanguage = '/app/profile/language';

  static const adminUsers = '/app/admin/users';
  static const adminSchemes = '/app/admin/schemes';
  static const adminMonitoring = '/app/admin/monitoring';
}
