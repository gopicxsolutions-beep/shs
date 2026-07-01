import { AreaChart, Area, BarChart, Bar, ResponsiveContainer, XAxis } from 'recharts'
import { Building2, Users, PiggyBank, Landmark, TrendingUp, GraduationCap } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { StatCard } from '../../components/ui/StatCard'
import { SectionHeader } from '../../components/ui/SectionHeader'
import { kpis, savingsTrend, loanTrendLakh, attendanceTrend, revenueTrend } from '../../data/analytics'

export function AnalyticsDashboard() {
  return (
    <div className="pb-6">
      <PageHeader title="Analytics Dashboard" subtitle="Federation-wide KPIs & trends" />

      <div className="px-4 mt-2">
        <SectionHeader title="Key Performance Indicators" icon={<TrendingUp className="h-4 w-4 text-ink-400" />} />
        <div className="grid grid-cols-2 gap-3">
          <StatCard label="Total SHGs" value={String(kpis.totalSHGs)} tone="brand" icon={<Building2 className="h-4 w-4" />} />
          <StatCard label="Active Members" value={kpis.activeMembers.toLocaleString('en-IN')} tone="ink" icon={<Users className="h-4 w-4" />} />
          <StatCard label="Total Savings" value={`₹${(kpis.totalSavings / 10000000).toFixed(2)}Cr`} tone="gold" icon={<PiggyBank className="h-4 w-4" />} />
          <StatCard label="Loans Disbursed" value={`₹${(kpis.loansDisbursed / 10000000).toFixed(2)}Cr`} tone="brand" icon={<Landmark className="h-4 w-4" />} />
          <StatCard label="Recovery Rate" value={`${kpis.recoveryRate}%`} tone="ink" icon={<TrendingUp className="h-4 w-4" />} />
          <StatCard label="Training Completion" value={`${kpis.trainingCompletion}%`} tone="gold" icon={<GraduationCap className="h-4 w-4" />} />
        </div>
      </div>

      <div className="px-4 mt-6">
        <SectionHeader title="Savings Trend" subtitle="₹ lakh · last 6 months" />
        <Card>
          <div className="h-40">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={savingsTrend}>
                <defs>
                  <linearGradient id="analyticsSavingsGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="#18ab7c" stopOpacity={0.4} />
                    <stop offset="100%" stopColor="#18ab7c" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <XAxis dataKey="month" tick={{ fontSize: 9, fill: '#647873' }} axisLine={false} tickLine={false} />
                <Area type="monotone" dataKey="value" stroke="#0e8a66" strokeWidth={2} fill="url(#analyticsSavingsGradient)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </Card>
      </div>

      <div className="px-4 mt-5">
        <SectionHeader title="Loan Disbursed vs Recovered" subtitle="₹ lakh · last 6 months" />
        <Card>
          <div className="h-40">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={loanTrendLakh}>
                <XAxis dataKey="month" tick={{ fontSize: 9, fill: '#647873' }} axisLine={false} tickLine={false} />
                <Bar dataKey="disbursed" fill="#f2900d" radius={[6, 6, 0, 0]} />
                <Bar dataKey="recovered" fill="#18ab7c" radius={[6, 6, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
          <div className="flex items-center gap-4 mt-2">
            <span className="flex items-center gap-1.5 text-[11px] text-ink-500"><span className="h-2 w-2 rounded-full bg-gold-500" /> Disbursed</span>
            <span className="flex items-center gap-1.5 text-[11px] text-ink-500"><span className="h-2 w-2 rounded-full bg-brand-500" /> Recovered</span>
          </div>
        </Card>
      </div>

      <div className="px-4 mt-5">
        <SectionHeader title="Attendance Trend" subtitle="% average · last 6 months" />
        <Card>
          <div className="h-40">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={attendanceTrend}>
                <XAxis dataKey="month" tick={{ fontSize: 9, fill: '#647873' }} axisLine={false} tickLine={false} />
                <Bar dataKey="value" fill="#0ea5e9" radius={[6, 6, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </Card>
      </div>

      <div className="px-4 mt-5">
        <SectionHeader title="Revenue Trend" subtitle="₹ lakh · last 6 months" />
        <Card>
          <div className="h-40">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={revenueTrend}>
                <defs>
                  <linearGradient id="revenueGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="#f2900d" stopOpacity={0.4} />
                    <stop offset="100%" stopColor="#f2900d" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <XAxis dataKey="month" tick={{ fontSize: 9, fill: '#647873' }} axisLine={false} tickLine={false} />
                <Area type="monotone" dataKey="value" stroke="#b56f0a" strokeWidth={2} fill="url(#revenueGradient)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </Card>
      </div>
    </div>
  )
}
