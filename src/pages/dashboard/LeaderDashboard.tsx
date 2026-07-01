import { Link } from 'react-router-dom'
import { Wallet, Landmark, Users, ClipboardCheck, FileBarChart, CalendarPlus, AlertTriangle } from 'lucide-react'
import { StatCard } from '../../components/ui/StatCard'
import { Card } from '../../components/ui/Card'
import { SectionHeader } from '../../components/ui/SectionHeader'
import { Badge } from '../../components/ui/Badge'
import { Avatar } from '../../components/ui/Avatar'
import { IconTile } from '../../components/ui/IconTile'
import { paths } from '../../routes/paths'
import { shgInfo } from '../../data/shg'
import { useData } from '../../context/DataContext'

export function LeaderDashboard() {
  const { loans, meetings } = useData()
  const pendingLoans = loans.filter((l) => l.status === 'pending')
  const overdueLoans = loans.filter((l) => l.status === 'overdue')
  const upcomingMeeting = meetings.find((m) => m.status === 'upcoming')

  return (
    <div className="pb-6">
      <div className="-mt-10 px-4">
        <div className="grid grid-cols-2 gap-3">
          <StatCard label="Group Savings" value={`₹${(shgInfo.totalSavings / 100000).toFixed(1)}L`} tone="brand" trend={`${shgInfo.memberCount} members`} icon={<Wallet className="h-4 w-4" />} />
          <StatCard label="Loans Outstanding" value={`₹${(shgInfo.totalLoans / 100000).toFixed(1)}L`} tone="gold" trend={`${overdueLoans.length} overdue`} icon={<Landmark className="h-4 w-4" />} />
        </div>
      </div>

      <div className="px-4 mt-5 grid grid-cols-4 gap-2">
        <IconTile to={paths.shgMembers} icon={<Users className="h-5.5 w-5.5" />} label="Members" tone="brand" />
        <IconTile to={paths.loanApproval} icon={<ClipboardCheck className="h-5.5 w-5.5" />} label="Approvals" tone="gold" badge={pendingLoans.length ? String(pendingLoans.length) : undefined} />
        <IconTile to={paths.meetingSchedule} icon={<CalendarPlus className="h-5.5 w-5.5" />} label="Schedule" tone="sky" />
        <IconTile to={paths.reportsShg} icon={<FileBarChart className="h-5.5 w-5.5" />} label="Reports" tone="violet" />
      </div>

      {overdueLoans.length > 0 && (
        <div className="px-4 mt-5">
          <Card className="flex items-center gap-3 bg-red-50 border-red-100">
            <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-red-100 text-red-600">
              <AlertTriangle className="h-5 w-5" />
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-bold text-red-700">{overdueLoans.length} Defaulter Alert{overdueLoans.length > 1 ? 's' : ''}</p>
              <p className="text-xs text-red-500 truncate">{overdueLoans[0].memberName} — EMI overdue since {overdueLoans[0].nextDueDate}</p>
            </div>
            <Link to={paths.loanTracking} className="text-xs font-semibold text-red-600 shrink-0">View</Link>
          </Card>
        </div>
      )}

      <div className="px-4 mt-5">
        <SectionHeader title="Pending Loan Approvals" action="Review all" actionTo={paths.loanApproval} />
        <Card className="divide-y divide-ink-100 !p-0">
          {pendingLoans.length === 0 && <p className="px-4 py-4 text-xs text-ink-400">No pending loan requests</p>}
          {pendingLoans.map((l) => (
            <div key={l.id} className="flex items-center gap-3 px-4 py-3">
              <Avatar name={l.memberName} size="sm" />
              <div className="min-w-0 flex-1">
                <p className="text-xs font-semibold text-ink-800 truncate">{l.memberName}</p>
                <p className="text-[11px] text-ink-400 truncate">{l.purpose}</p>
              </div>
              <Badge tone="warning">₹{l.amount.toLocaleString('en-IN')}</Badge>
            </div>
          ))}
        </Card>
      </div>

      {upcomingMeeting && (
        <div className="px-4 mt-5">
          <SectionHeader title="Next Meeting" action="Manage" actionTo={paths.meetings} />
          <Card className="flex items-center gap-3">
            <div className="flex h-12 w-12 shrink-0 flex-col items-center justify-center rounded-xl bg-brand-50 text-brand-700">
              <span className="text-[10px] font-bold uppercase leading-none">{upcomingMeeting.date.split(' ')[1]}</span>
              <span className="text-base font-bold leading-none">{upcomingMeeting.date.split(' ')[0]}</span>
            </div>
            <div className="min-w-0 flex-1">
              <p className="text-sm font-semibold text-ink-900 truncate">{upcomingMeeting.agenda}</p>
              <p className="text-xs text-ink-500">{upcomingMeeting.time} · {upcomingMeeting.venue}</p>
            </div>
          </Card>
        </div>
      )}

      <div className="px-4 mt-5">
        <SectionHeader title="SHG Health" />
        <div className="grid grid-cols-3 gap-3">
          <Card className="!p-3 text-center">
            <p className="text-lg font-bold text-brand-700 font-display">{shgInfo.grade}</p>
            <p className="text-[10px] text-ink-500 mt-0.5">Grading</p>
          </Card>
          <Card className="!p-3 text-center">
            <p className="text-lg font-bold text-brand-700 font-display">96%</p>
            <p className="text-[10px] text-ink-500 mt-0.5">Attendance</p>
          </Card>
          <Card className="!p-3 text-center">
            <p className="text-lg font-bold text-brand-700 font-display">94%</p>
            <p className="text-[10px] text-ink-500 mt-0.5">Recovery</p>
          </Card>
        </div>
      </div>
    </div>
  )
}
