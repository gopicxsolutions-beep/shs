import { Navigate, Route, Routes } from 'react-router-dom'
import { AppShell } from '../components/layout/AppShell'
import { SubPageShell } from '../components/layout/SubPageShell'
import { paths } from './paths'

import { Splash } from '../pages/auth/Splash'
import { Login } from '../pages/auth/Login'
import { Otp } from '../pages/auth/Otp'
import { ProfileSetup } from '../pages/auth/ProfileSetup'
import { RoleSelect } from '../pages/auth/RoleSelect'

import { Dashboard } from '../pages/dashboard/Dashboard'
import { Services } from '../pages/services/Services'

import { MySHG } from '../pages/shg/MySHG'
import { MemberDirectory } from '../pages/shg/MemberDirectory'
import { MemberProfile } from '../pages/shg/MemberProfile'
import { Documents } from '../pages/shg/Documents'

import { SavingsHome } from '../pages/savings/SavingsHome'
import { SavingsEntry } from '../pages/savings/SavingsEntry'
import { SavingsHistory } from '../pages/savings/SavingsHistory'
import { SavingsLedger } from '../pages/savings/SavingsLedger'
import { SavingsStatement } from '../pages/savings/SavingsStatement'
import { GroupSavingsReport } from '../pages/savings/GroupSavingsReport'

import { LoanHome } from '../pages/loans/LoanHome'
import { LoanApply } from '../pages/loans/LoanApply'
import { LoanApproval } from '../pages/loans/LoanApproval'
import { LoanTracking } from '../pages/loans/LoanTracking'
import { LoanDetail } from '../pages/loans/LoanDetail'

import { MeetingsHome } from '../pages/meetings/MeetingsHome'
import { MeetingSchedule } from '../pages/meetings/MeetingSchedule'
import { MeetingAttendance } from '../pages/meetings/MeetingAttendance'
import { MeetingQr } from '../pages/meetings/MeetingQr'
import { MeetingDetail } from '../pages/meetings/MeetingDetail'
import { MeetingMom } from '../pages/meetings/MeetingMom'

import { CashBook } from '../pages/financial/CashBook'
import { Ledger } from '../pages/financial/Ledger'
import { BankAccount } from '../pages/financial/BankAccount'
import { AuditRecords } from '../pages/financial/AuditRecords'

import { LivelihoodHome } from '../pages/livelihood/LivelihoodHome'
import { LivelihoodEntry } from '../pages/livelihood/LivelihoodEntry'
import { LivelihoodDetail } from '../pages/livelihood/LivelihoodDetail'

import { MarketplaceHome } from '../pages/marketplace/MarketplaceHome'
import { ProductDetail } from '../pages/marketplace/ProductDetail'
import { AddProduct } from '../pages/marketplace/AddProduct'
import { Orders } from '../pages/marketplace/Orders'
import { OrderDetail } from '../pages/marketplace/OrderDetail'
import { Reviews } from '../pages/marketplace/Reviews'

import { SchemeRepository } from '../pages/schemes/SchemeRepository'
import { SchemeDetail } from '../pages/schemes/SchemeDetail'
import { EligibilityChecker } from '../pages/schemes/EligibilityChecker'
import { ApplicationTracking } from '../pages/schemes/ApplicationTracking'

import { TrainingHome } from '../pages/training/TrainingHome'
import { CourseDetail } from '../pages/training/CourseDetail'
import { Quiz } from '../pages/training/Quiz'
import { Certificates } from '../pages/training/Certificates'

import { PaymentsHome } from '../pages/payments/PaymentsHome'
import { QrPay } from '../pages/payments/QrPay'
import { PaymentHistory } from '../pages/payments/PaymentHistory'

import { AnnouncementsHome } from '../pages/announcements/AnnouncementsHome'
import { AnnouncementDetail } from '../pages/announcements/AnnouncementDetail'

import { SupportHome } from '../pages/support/SupportHome'
import { ChatSupport } from '../pages/support/ChatSupport'
import { VoiceAssistant } from '../pages/support/VoiceAssistant'
import { FAQ } from '../pages/support/FAQ'
import { RaiseTicket } from '../pages/support/RaiseTicket'

import { AIHub } from '../pages/ai/AIHub'
import { FinancialAdvisor } from '../pages/ai/FinancialAdvisor'
import { SchemeRecommender } from '../pages/ai/SchemeRecommender'
import { MarketAdvisor } from '../pages/ai/MarketAdvisor'

import { ReportsHome } from '../pages/reports/ReportsHome'
import { MemberReports } from '../pages/reports/MemberReports'
import { SHGReports } from '../pages/reports/SHGReports'
import { FederationReports } from '../pages/reports/FederationReports'

import { AnalyticsDashboard } from '../pages/analytics/AnalyticsDashboard'

import { Profile } from '../pages/profile/Profile'
import { Settings } from '../pages/profile/Settings'
import { LanguageSelect } from '../pages/profile/LanguageSelect'

import { UserManagement } from '../pages/admin/UserManagement'
import { SchemeManagement } from '../pages/admin/SchemeManagement'
import { SystemMonitoring } from '../pages/admin/SystemMonitoring'

export function AppRouter() {
  return (
    <Routes>
      <Route path={paths.splash} element={<Splash />} />
      <Route path={paths.login} element={<Login />} />
      <Route path={paths.otp} element={<Otp />} />
      <Route path={paths.profileSetup} element={<ProfileSetup />} />
      <Route path={paths.roleSelect} element={<RoleSelect />} />

      <Route element={<AppShell />}>
        <Route path={paths.dashboard} element={<Dashboard />} />
        <Route path={paths.shg} element={<MySHG />} />
        <Route path={paths.services} element={<Services />} />
        <Route path={paths.marketplace} element={<MarketplaceHome />} />
        <Route path={paths.profile} element={<Profile />} />
      </Route>

      <Route element={<SubPageShell />}>
        <Route path={paths.shgMembers} element={<MemberDirectory />} />
        <Route path="/app/shg/members/:id" element={<MemberProfile />} />
        <Route path={paths.shgDocuments} element={<Documents />} />

        <Route path={paths.savings} element={<SavingsHome />} />
        <Route path={paths.savingsEntry} element={<SavingsEntry />} />
        <Route path={paths.savingsHistory} element={<SavingsHistory />} />
        <Route path={paths.savingsLedger} element={<SavingsLedger />} />
        <Route path={paths.savingsStatement} element={<SavingsStatement />} />
        <Route path={paths.savingsGroupReport} element={<GroupSavingsReport />} />

        <Route path={paths.loans} element={<LoanHome />} />
        <Route path={paths.loanApply} element={<LoanApply />} />
        <Route path={paths.loanApproval} element={<LoanApproval />} />
        <Route path={paths.loanTracking} element={<LoanTracking />} />
        <Route path="/app/loans/:id" element={<LoanDetail />} />

        <Route path={paths.meetings} element={<MeetingsHome />} />
        <Route path={paths.meetingSchedule} element={<MeetingSchedule />} />
        <Route path={paths.meetingAttendance} element={<MeetingAttendance />} />
        <Route path={paths.meetingQr} element={<MeetingQr />} />
        <Route path="/app/meetings/:id/mom" element={<MeetingMom />} />
        <Route path="/app/meetings/:id" element={<MeetingDetail />} />

        <Route path={paths.financialCashbook} element={<CashBook />} />
        <Route path={paths.financialLedger} element={<Ledger />} />
        <Route path={paths.financialBank} element={<BankAccount />} />
        <Route path={paths.financialAudit} element={<AuditRecords />} />

        <Route path={paths.livelihood} element={<LivelihoodHome />} />
        <Route path={paths.livelihoodEntry} element={<LivelihoodEntry />} />
        <Route path="/app/livelihood/:id" element={<LivelihoodDetail />} />

        <Route path={paths.marketplaceAddProduct} element={<AddProduct />} />
        <Route path={paths.marketplaceOrders} element={<Orders />} />
        <Route path="/app/marketplace/orders/:id" element={<OrderDetail />} />
        <Route path={paths.marketplaceReviews} element={<Reviews />} />
        <Route path="/app/marketplace/product/:id" element={<ProductDetail />} />

        <Route path={paths.schemes} element={<SchemeRepository />} />
        <Route path={paths.schemeEligibility} element={<EligibilityChecker />} />
        <Route path={paths.schemeTracking} element={<ApplicationTracking />} />
        <Route path="/app/schemes/:id" element={<SchemeDetail />} />

        <Route path={paths.training} element={<TrainingHome />} />
        <Route path={paths.trainingCertificates} element={<Certificates />} />
        <Route path="/app/training/:id/quiz" element={<Quiz />} />
        <Route path="/app/training/:id" element={<CourseDetail />} />

        <Route path={paths.payments} element={<PaymentsHome />} />
        <Route path={paths.paymentsQr} element={<QrPay />} />
        <Route path={paths.paymentsHistory} element={<PaymentHistory />} />

        <Route path={paths.announcements} element={<AnnouncementsHome />} />
        <Route path="/app/announcements/:id" element={<AnnouncementDetail />} />

        <Route path={paths.support} element={<SupportHome />} />
        <Route path={paths.supportChat} element={<ChatSupport />} />
        <Route path={paths.supportVoice} element={<VoiceAssistant />} />
        <Route path={paths.supportFaq} element={<FAQ />} />
        <Route path={paths.supportTicket} element={<RaiseTicket />} />

        <Route path={paths.aiHub} element={<AIHub />} />
        <Route path={paths.aiFinancialAdvisor} element={<FinancialAdvisor />} />
        <Route path={paths.aiSchemeRecommender} element={<SchemeRecommender />} />
        <Route path={paths.aiMarketAdvisor} element={<MarketAdvisor />} />

        <Route path={paths.reports} element={<ReportsHome />} />
        <Route path={paths.reportsMember} element={<MemberReports />} />
        <Route path={paths.reportsShg} element={<SHGReports />} />
        <Route path={paths.reportsFederation} element={<FederationReports />} />

        <Route path={paths.analytics} element={<AnalyticsDashboard />} />

        <Route path={paths.profileSettings} element={<Settings />} />
        <Route path={paths.profileLanguage} element={<LanguageSelect />} />

        <Route path={paths.adminUsers} element={<UserManagement />} />
        <Route path={paths.adminSchemes} element={<SchemeManagement />} />
        <Route path={paths.adminMonitoring} element={<SystemMonitoring />} />
      </Route>

      <Route path="*" element={<Navigate to={paths.splash} replace />} />
    </Routes>
  )
}
