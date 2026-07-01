import { AreaChart, Area, BarChart, Bar, ResponsiveContainer, XAxis } from 'recharts'
import { Building2, TrendingUp, PiggyBank } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { StatCard } from '../../components/ui/StatCard'
import { SectionHeader } from '../../components/ui/SectionHeader'
import { villageWiseSHGs, savingsTrend, loanTrendLakh, kpis } from '../../data/analytics'

export function FederationReports() {
  const totalShgs = villageWiseSHGs.reduce((s, v) => s + v.shgs, 0)
  const totalVillageSavings = villageWiseSHGs.reduce((s, v) => s + v.savings, 0)

  return (
    <div className="pb-6">
      <PageHeader title="Federation Reports" subtitle="Village-wise SHGs, recovery & savings growth" />

      <div className="px-4 mt-2 grid grid-cols-2 gap-3">
        <StatCard label="Total SHGs" value={String(totalShgs)} tone="brand" trend={`${villageWiseSHGs.length} villages`} icon={<Building2 className="h-4 w-4" />} />
        <StatCard label="Loan Recovery" value={`${kpis.recoveryRate}%`} tone="gold" trend="Federation-wide" icon={<TrendingUp className="h-4 w-4" />} />
      </div>

      <div className="px-4 mt-6">
        <SectionHeader title="Village-wise SHGs" icon={<Building2 className="h-4 w-4 text-ink-400" />} />
        <Card>
          <div className="h-40">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={villageWiseSHGs}>
                <XAxis dataKey="village" tick={{ fontSize: 9, fill: '#647873' }} axisLine={false} tickLine={false} interval={0} angle={-20} textAnchor="end" height={40} />
                <Bar dataKey="shgs" fill="#18ab7c" radius={[6, 6, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
          <p className="mt-2 text-[11px] text-ink-400 text-right">
            Total village savings: ₹{(totalVillageSavings / 10000000).toFixed(2)}Cr
          </p>
        </Card>
      </div>

      <div className="px-4 mt-5">
        <SectionHeader title="Loan Disbursed vs Recovered" subtitle="₹ lakh · last 6 months" icon={<PiggyBank className="h-4 w-4 text-ink-400" />} />
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
        <SectionHeader title="Savings Growth" subtitle="₹ lakh · last 6 months" />
        <Card>
          <div className="h-40">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={savingsTrend}>
                <defs>
                  <linearGradient id="fedSavingsGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="#18ab7c" stopOpacity={0.4} />
                    <stop offset="100%" stopColor="#18ab7c" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <XAxis dataKey="month" tick={{ fontSize: 9, fill: '#647873' }} axisLine={false} tickLine={false} />
                <Area type="monotone" dataKey="value" stroke="#0e8a66" strokeWidth={2} fill="url(#fedSavingsGradient)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </Card>
      </div>
    </div>
  )
}
