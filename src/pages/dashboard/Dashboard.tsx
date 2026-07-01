import { useApp } from '../../context/AppContext'
import { DashboardTopBar } from './DashboardTopBar'
import { MemberDashboard } from './MemberDashboard'
import { LeaderDashboard } from './LeaderDashboard'
import { CRPDashboard } from './CRPDashboard'
import { CLFDashboard } from './CLFDashboard'
import { AdminDashboard } from './AdminDashboard'

export function Dashboard() {
  const { user } = useApp()

  return (
    <div>
      <DashboardTopBar />
      {user.role === 'member' && <MemberDashboard />}
      {user.role === 'leader' && <LeaderDashboard />}
      {user.role === 'crp' && <CRPDashboard />}
      {user.role === 'clf' && <CLFDashboard />}
      {user.role === 'admin' && <AdminDashboard />}
    </div>
  )
}
