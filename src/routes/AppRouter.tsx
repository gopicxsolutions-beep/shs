import { Navigate, Route, Routes } from 'react-router-dom'
import { AppShell } from '../components/layout/AppShell'
import { SubPageShell } from '../components/layout/SubPageShell'
import { ComingSoon } from '../components/ui/ComingSoon'
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
        <Route path={paths.marketplace} element={<ComingSoon title="Marketplace" />} />
        <Route path={paths.profile} element={<ComingSoon title="Profile" />} />
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

        <Route path="/app/*" element={<ComingSoon title="Coming soon" />} />
      </Route>

      <Route path="*" element={<Navigate to={paths.splash} replace />} />
    </Routes>
  )
}
