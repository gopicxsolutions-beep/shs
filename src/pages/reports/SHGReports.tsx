import { AreaChart, Area, ResponsiveContainer, XAxis } from 'recharts'
import { ShieldCheck, PiggyBank, Landmark, CalendarCheck2 } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { StatCard } from '../../components/ui/StatCard'
import { Badge } from '../../components/ui/Badge'
import { SectionHeader } from '../../components/ui/SectionHeader'
import { savingsMonthlyTrend } from '../../data/savings'
import { members } from '../../data/members'
import { useData } from '../../context/DataContext'

export function SHGReports() {
  const { savingsEntries, loans } = useData()
  const totalSavingsCollected = savingsEntries.reduce((s, e) => s + e.amount, 0)
  const totalDisbursed = loans.reduce((s, l) => s + l.amount, 0)
  const totalOutstanding = loans.reduce((s, l) => s + l.outstanding, 0)
  const recovered = totalDisbursed - totalOutstanding
  const recoveryRate = totalDisbursed > 0 ? Math.round((recovered / totalDisbursed) * 100) : 0
  const avgAttendance = Math.round(members.reduce((s, m) => s + m.attendance, 0) / members.length)

  return (
    <div className="pb-6">
      <PageHeader title="SHG Reports" subtitle="Financial summary, audit & performance" />

      <div className="px-4 mt-2 grid grid-cols-2 gap-3">
        <StatCard label="Savings Collected" value={`₹${totalSavingsCollected.toLocaleString('en-IN')}`} tone="brand" trend="Recent entries" icon={<PiggyBank className="h-4 w-4" />} />
        <StatCard label="Loans Disbursed" value={`₹${totalDisbursed.toLocaleString('en-IN')}`} tone="gold" trend={`₹${totalOutstanding.toLocaleString('en-IN')} outstanding`} icon={<Landmark className="h-4 w-4" />} />
      </div>

      <div className="px-4 mt-5">
        <SectionHeader title="Audit Report" icon={<ShieldCheck className="h-4 w-4 text-ink-400" />} />
        <Card className="flex items-center justify-between">
          <div>
            <p className="text-sm font-bold text-ink-900">Latest Audit Status</p>
            <p className="text-xs text-ink-500 mt-0.5">Books reconciled · No discrepancies found</p>
          </div>
          <Badge tone="success">Clean</Badge>
        </Card>
      </div>

      <div className="px-4 mt-5">
        <SectionHeader title="Performance Report" icon={<CalendarCheck2 className="h-4 w-4 text-ink-400" />} />
        <div className="grid grid-cols-2 gap-3">
          <Card className="!p-3.5">
            <p className="text-xs text-ink-500">Avg. Attendance</p>
            <p className="text-lg font-bold font-display text-ink-900 mt-1">{avgAttendance}%</p>
          </Card>
          <Card className="!p-3.5">
            <p className="text-xs text-ink-500">Loan Recovery Rate</p>
            <p className="text-lg font-bold font-display text-brand-700 mt-1">{recoveryRate}%</p>
          </Card>
        </div>
      </div>

      <div className="px-4 mt-5">
        <SectionHeader title="Savings Trend" subtitle="Monthly collection · last 6 months" />
        <Card>
          <div className="h-40">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={savingsMonthlyTrend}>
                <defs>
                  <linearGradient id="shgSavingsGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="#18ab7c" stopOpacity={0.4} />
                    <stop offset="100%" stopColor="#18ab7c" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <XAxis dataKey="month" tick={{ fontSize: 9, fill: '#647873' }} axisLine={false} tickLine={false} />
                <Area type="monotone" dataKey="amount" stroke="#0e8a66" strokeWidth={2} fill="url(#shgSavingsGradient)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </Card>
      </div>
    </div>
  )
}
