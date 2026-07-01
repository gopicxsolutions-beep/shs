import { Link } from 'react-router-dom'
import { BarChart, Bar, ResponsiveContainer, XAxis } from 'recharts'
import { Landmark, Building2, PiggyBank, LineChart } from 'lucide-react'
import { StatCard } from '../../components/ui/StatCard'
import { Card } from '../../components/ui/Card'
import { SectionHeader } from '../../components/ui/SectionHeader'
import { paths } from '../../routes/paths'
import { kpis, villageWiseSHGs } from '../../data/analytics'

export function CLFDashboard() {
  return (
    <div className="pb-6">
      <div className="-mt-10 px-4">
        <div className="grid grid-cols-2 gap-3">
          <StatCard label="Village Orgs" value={String(villageWiseSHGs.length)} tone="brand" trend={`${kpis.totalSHGs} SHGs total`} icon={<Building2 className="h-4 w-4" />} />
          <StatCard label="Total Savings" value={`₹${(kpis.totalSavings / 10000000).toFixed(2)}Cr`} tone="gold" trend="Financial oversight" icon={<PiggyBank className="h-4 w-4" />} />
        </div>
      </div>

      <div className="px-4 mt-6">
        <SectionHeader title="Village-wise SHGs" action="Federation reports" actionTo={paths.reportsFederation} icon={<Building2 className="h-4 w-4 text-ink-400" />} />
        <Card>
          <div className="h-40">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={villageWiseSHGs}>
                <XAxis dataKey="village" tick={{ fontSize: 9, fill: '#647873' }} axisLine={false} tickLine={false} interval={0} angle={-20} textAnchor="end" height={40} />
                <Bar dataKey="shgs" fill="#18ab7c" radius={[6, 6, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </Card>
      </div>

      <div className="px-4 mt-5">
        <SectionHeader title="Financial Oversight" icon={<Landmark className="h-4 w-4 text-ink-400" />} />
        <div className="grid grid-cols-2 gap-3">
          <Card className="!p-3.5">
            <p className="text-xs text-ink-500">Loans Disbursed</p>
            <p className="text-lg font-bold font-display text-ink-900 mt-1">₹{(kpis.loansDisbursed / 10000000).toFixed(2)}Cr</p>
          </Card>
          <Card className="!p-3.5">
            <p className="text-xs text-ink-500">Recovery Rate</p>
            <p className="text-lg font-bold font-display text-brand-700 mt-1">{kpis.recoveryRate}%</p>
          </Card>
        </div>
      </div>

      <div className="px-4 mt-5">
        <Card
          className="flex items-center gap-3 bg-gradient-to-r from-brand-700 to-brand-600 text-white"
        >
          <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl bg-white/15">
            <LineChart className="h-5 w-5" />
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-sm font-bold">Full Analytics Dashboard</p>
            <p className="text-xs text-white/70">KPIs, trends & recovery insights</p>
          </div>
          <Link to={paths.analytics} className="text-xs font-semibold shrink-0">Open</Link>
        </Card>
      </div>
    </div>
  )
}
