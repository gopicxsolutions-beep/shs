import { AreaChart, Area, ResponsiveContainer, XAxis } from 'recharts'
import { PlusCircle, History, BookText, FileBarChart2, Wallet } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { StatCard } from '../../components/ui/StatCard'
import { SectionHeader } from '../../components/ui/SectionHeader'
import { Badge } from '../../components/ui/Badge'
import { IconTile } from '../../components/ui/IconTile'
import { paths } from '../../routes/paths'
import { savingsMonthlyTrend } from '../../data/savings'
import { shgInfo } from '../../data/shg'
import { useData } from '../../context/DataContext'

export function SavingsHome() {
  const { savingsEntries } = useData()
  return (
    <div className="pb-6">
      <PageHeader title="Savings Management" subtitle={shgInfo.name} />

      <div className="px-4 mt-2 grid grid-cols-2 gap-3">
        <StatCard label="My Savings" value="₹48,200" tone="brand" trend="+₹500 this week" icon={<Wallet className="h-4 w-4" />} />
        <StatCard label="Group Savings" value={`₹${(shgInfo.totalSavings / 100000).toFixed(1)}L`} tone="gold" trend={`${shgInfo.memberCount} members`} icon={<Wallet className="h-4 w-4" />} />
      </div>

      <div className="px-4 mt-5 grid grid-cols-4 gap-2">
        <IconTile to={paths.savingsEntry} icon={<PlusCircle className="h-5.5 w-5.5" />} label="New Entry" tone="brand" />
        <IconTile to={paths.savingsHistory} icon={<History className="h-5.5 w-5.5" />} label="History" tone="gold" />
        <IconTile to={paths.savingsLedger} icon={<BookText className="h-5.5 w-5.5" />} label="Ledger" tone="sky" />
        <IconTile to={paths.savingsGroupReport} icon={<FileBarChart2 className="h-5.5 w-5.5" />} label="Group Report" tone="violet" />
      </div>

      <div className="px-4 mt-6">
        <SectionHeader title="Savings Trend" subtitle="Last 6 months" />
        <Card>
          <div className="h-40">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={savingsMonthlyTrend}>
                <defs>
                  <linearGradient id="svHomeGrad" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="#18ab7c" stopOpacity={0.45} />
                    <stop offset="100%" stopColor="#18ab7c" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <XAxis dataKey="month" tick={{ fontSize: 10, fill: '#647873' }} axisLine={false} tickLine={false} />
                <Area type="monotone" dataKey="amount" stroke="#0e8a66" strokeWidth={2} fill="url(#svHomeGrad)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </Card>
      </div>

      <div className="px-4 mt-5">
        <SectionHeader title="Recent Entries" action="View statement" actionTo={paths.savingsStatement} />
        <Card className="!p-0 divide-y divide-ink-100">
          {savingsEntries.slice(0, 5).map((s) => (
            <div key={s.id} className="flex items-center justify-between px-4 py-3">
              <div className="min-w-0">
                <p className="text-xs font-semibold text-ink-800 truncate">{s.memberName}</p>
                <p className="text-[11px] text-ink-400">{s.date} · {s.mode}</p>
              </div>
              <div className="text-right shrink-0">
                <p className="text-sm font-bold text-brand-700">+₹{s.amount}</p>
                <Badge tone={s.status === 'verified' ? 'success' : 'warning'}>{s.status}</Badge>
              </div>
            </div>
          ))}
        </Card>
      </div>
    </div>
  )
}
