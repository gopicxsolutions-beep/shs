import { Link } from 'react-router-dom'
import { AreaChart, Area, ResponsiveContainer } from 'recharts'
import { Wallet, Landmark, CalendarClock, GraduationCap, QrCode, FileText, CheckSquare, Sparkles } from 'lucide-react'
import { StatCard } from '../../components/ui/StatCard'
import { Card } from '../../components/ui/Card'
import { SectionHeader } from '../../components/ui/SectionHeader'
import { ProgressBar } from '../../components/ui/ProgressBar'
import { Badge } from '../../components/ui/Badge'
import { IconTile } from '../../components/ui/IconTile'
import { paths } from '../../routes/paths'
import { savingsMonthlyTrend } from '../../data/savings'
import { loans } from '../../data/loans'
import { meetings } from '../../data/meetings'
import { courses } from '../../data/training'
import { announcements } from '../../data/announcements'
import { shgInfo } from '../../data/shg'

export function MemberDashboard() {
  const myLoan = loans.find((l) => l.memberName === 'Lakshmi Devi' && l.status === 'active')
  const upcomingMeeting = meetings.find((m) => m.status === 'upcoming')
  const inProgressCourse = courses.find((c) => c.progress > 0 && c.progress < 100)

  return (
    <div className="pb-6">
      <div className="-mt-10 px-4">
        <div className="grid grid-cols-2 gap-3">
          <StatCard label="My Savings" value="₹48,200" tone="brand" trend="+₹500 this week" icon={<Wallet className="h-4 w-4" />} />
          <StatCard label="Outstanding Loan" value="₹22,000" tone="gold" trend="Next EMI 10 Jul" icon={<Landmark className="h-4 w-4" />} />
        </div>
      </div>

      <div className="px-4 mt-5 grid grid-cols-4 gap-2">
        <IconTile to={paths.savingsEntry} icon={<Wallet className="h-5.5 w-5.5" />} label="Add Savings" tone="brand" />
        <IconTile to={paths.loanApply} icon={<Landmark className="h-5.5 w-5.5" />} label="Apply Loan" tone="gold" />
        <IconTile to={paths.meetingQr} icon={<QrCode className="h-5.5 w-5.5" />} label="Attendance" tone="sky" />
        <IconTile to={paths.schemes} icon={<FileText className="h-5.5 w-5.5" />} label="Schemes" tone="violet" />
      </div>

      <div className="px-4 mt-6">
        <SectionHeader title="Savings Summary" action="View all" actionTo={paths.savings} />
        <Card>
          <div className="flex items-center justify-between">
            <div>
              <p className="text-2xl font-bold font-display text-ink-900">₹48,200</p>
              <p className="text-xs text-ink-500 mt-1">Group total: ₹{shgInfo.totalSavings.toLocaleString('en-IN')}</p>
            </div>
            <Badge tone="success">+18% YoY</Badge>
          </div>
          <div className="h-16 mt-2 -mx-1">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={savingsMonthlyTrend}>
                <defs>
                  <linearGradient id="savingsGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="#18ab7c" stopOpacity={0.4} />
                    <stop offset="100%" stopColor="#18ab7c" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <Area type="monotone" dataKey="amount" stroke="#0e8a66" strokeWidth={2} fill="url(#savingsGradient)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </Card>
      </div>

      {myLoan && (
        <div className="px-4 mt-5">
          <SectionHeader title="Loan Summary" action="Track" actionTo={paths.loanTracking} />
          <Card>
            <p className="text-xs text-ink-500">{myLoan.purpose}</p>
            <div className="flex items-end justify-between mt-2">
              <p className="text-lg font-bold font-display text-ink-900">₹{myLoan.outstanding.toLocaleString('en-IN')}</p>
              <p className="text-xs text-ink-500">of ₹{myLoan.amount.toLocaleString('en-IN')}</p>
            </div>
            <ProgressBar value={myLoan.amount - myLoan.outstanding} max={myLoan.amount} tone="gold" className="mt-2" />
            <div className="flex items-center justify-between mt-3">
              <Badge tone="warning" dot>EMI ₹{myLoan.emi} due {myLoan.nextDueDate}</Badge>
              <Link to={paths.paymentsQr} className="text-xs font-semibold text-brand-600">Pay now</Link>
            </div>
          </Card>
        </div>
      )}

      <div className="px-4 mt-5 grid grid-cols-2 gap-3">
        {upcomingMeeting && (
          <Card className="!p-3.5">
            <div className="flex items-center gap-1.5 text-brand-600">
              <CalendarClock className="h-4 w-4" />
              <span className="text-[11px] font-bold">MEETING ALERT</span>
            </div>
            <p className="text-sm font-bold text-ink-900 mt-1.5">{upcomingMeeting.date}</p>
            <p className="text-[11px] text-ink-500 mt-0.5 line-clamp-2">{upcomingMeeting.agenda}</p>
            <Link to={paths.meetings} className="mt-2 inline-block text-[11px] font-semibold text-brand-600">Details</Link>
          </Card>
        )}
        {inProgressCourse && (
          <Card className="!p-3.5">
            <div className="flex items-center gap-1.5 text-gold-600">
              <GraduationCap className="h-4 w-4" />
              <span className="text-[11px] font-bold">TRAINING ALERT</span>
            </div>
            <p className="text-sm font-bold text-ink-900 mt-1.5 line-clamp-1">{inProgressCourse.title}</p>
            <ProgressBar value={inProgressCourse.progress} tone="gold" className="mt-2" />
            <Link to={paths.trainingDetail(inProgressCourse.id)} className="mt-2 inline-block text-[11px] font-semibold text-gold-600">Continue</Link>
          </Card>
        )}
      </div>

      <div className="px-4 mt-5">
        <Card className="flex items-center gap-3 bg-gradient-to-r from-violet-50 to-white">
          <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl bg-violet-100 text-violet-600">
            <Sparkles className="h-5 w-5" />
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-sm font-bold text-ink-900">AI Financial Advisor</p>
            <p className="text-xs text-ink-500 truncate">Your credit score estimate: 742 (Good)</p>
          </div>
          <Link to={paths.aiFinancialAdvisor} className="text-xs font-semibold text-violet-600 shrink-0">View</Link>
        </Card>
      </div>

      <div className="px-4 mt-5">
        <SectionHeader title="Recent Announcements" action="See all" actionTo={paths.announcements} icon={<CheckSquare className="h-4 w-4 text-ink-400" />} />
        <Card className="divide-y divide-ink-100 !p-0">
          {announcements.slice(0, 3).map((a) => (
            <Link key={a.id} to={paths.announcementDetail(a.id)} className="flex items-start gap-2 px-4 py-3">
              {!a.read && <span className="mt-1.5 h-1.5 w-1.5 shrink-0 rounded-full bg-brand-500" />}
              <div className={a.read ? 'ml-3.5' : ''}>
                <p className="text-xs font-semibold text-ink-800 line-clamp-1">{a.title}</p>
                <p className="text-[11px] text-ink-400 mt-0.5">{a.date}</p>
              </div>
            </Link>
          ))}
        </Card>
      </div>
    </div>
  )
}
