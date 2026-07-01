export const paths = {
  splash: '/',
  login: '/login',
  otp: '/otp',
  profileSetup: '/profile-setup',
  roleSelect: '/role-select',

  dashboard: '/app/dashboard',
  shg: '/app/shg',
  services: '/app/services',
  marketplace: '/app/marketplace',
  profile: '/app/profile',

  shgMembers: '/app/shg/members',
  shgMember: (id: string) => `/app/shg/members/${id}`,
  shgDocuments: '/app/shg/documents',

  savings: '/app/savings',
  savingsEntry: '/app/savings/entry',
  savingsHistory: '/app/savings/history',
  savingsLedger: '/app/savings/ledger',
  savingsStatement: '/app/savings/statement',
  savingsGroupReport: '/app/savings/group-report',

  loans: '/app/loans',
  loanApply: '/app/loans/apply',
  loanApproval: '/app/loans/approval',
  loanTracking: '/app/loans/tracking',
  loanDetail: (id: string) => `/app/loans/${id}`,

  meetings: '/app/meetings',
  meetingSchedule: '/app/meetings/schedule',
  meetingAttendance: '/app/meetings/attendance',
  meetingQr: '/app/meetings/qr-attendance',
  meetingDetail: (id: string) => `/app/meetings/${id}`,
  meetingMom: (id: string) => `/app/meetings/${id}/mom`,

  financialCashbook: '/app/financial/cashbook',
  financialLedger: '/app/financial/ledger',
  financialBank: '/app/financial/bank',
  financialAudit: '/app/financial/audit',

  livelihood: '/app/livelihood',
  livelihoodEntry: '/app/livelihood/entry',
  livelihoodDetail: (id: string) => `/app/livelihood/${id}`,

  marketplaceProduct: (id: string) => `/app/marketplace/product/${id}`,
  marketplaceAddProduct: '/app/marketplace/add-product',
  marketplaceOrders: '/app/marketplace/orders',
  marketplaceOrderDetail: (id: string) => `/app/marketplace/orders/${id}`,
  marketplaceReviews: '/app/marketplace/reviews',

  schemes: '/app/schemes',
  schemeDetail: (id: string) => `/app/schemes/${id}`,
  schemeEligibility: '/app/schemes/eligibility',
  schemeTracking: '/app/schemes/tracking',

  training: '/app/training',
  trainingDetail: (id: string) => `/app/training/${id}`,
  trainingQuiz: (id: string) => `/app/training/${id}/quiz`,
  trainingCertificates: '/app/training/certificates',

  payments: '/app/payments',
  paymentsQr: '/app/payments/qr',
  paymentsHistory: '/app/payments/history',

  announcements: '/app/announcements',
  announcementDetail: (id: string) => `/app/announcements/${id}`,

  support: '/app/support',
  supportChat: '/app/support/chat',
  supportVoice: '/app/support/voice',
  supportFaq: '/app/support/faq',
  supportTicket: '/app/support/ticket',

  aiHub: '/app/ai',
  aiFinancialAdvisor: '/app/ai/financial-advisor',
  aiSchemeRecommender: '/app/ai/scheme-recommender',
  aiMarketAdvisor: '/app/ai/market-advisor',

  reports: '/app/reports',
  reportsMember: '/app/reports/member',
  reportsShg: '/app/reports/shg',
  reportsFederation: '/app/reports/federation',

  analytics: '/app/analytics',
  analyticsShgList: '/app/analytics/shgs',
  analyticsShgDetail: (id: string) => `/app/analytics/shg/${id}`,

  profileSettings: '/app/profile/settings',
  profileLanguage: '/app/profile/language',

  adminUsers: '/app/admin/users',
  adminSchemes: '/app/admin/schemes',
  adminMonitoring: '/app/admin/monitoring',
}
