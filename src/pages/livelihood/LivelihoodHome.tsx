import { Link } from 'react-router-dom'
import { PlusCircle, Sprout, TrendingUp, Wallet } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { StatCard } from '../../components/ui/StatCard'
import { SectionHeader } from '../../components/ui/SectionHeader'
import { Badge } from '../../components/ui/Badge'
import { IconTile } from '../../components/ui/IconTile'
import { paths } from '../../routes/paths'
import { activities, categoryMeta } from '../../data/livelihood'

export function LivelihoodHome() {
  const totalIncome = activities.reduce((sum, a) => sum + a.income, 0)
  const totalExpense = activities.reduce((sum, a) => sum + a.expense, 0)

  const categories = Array.from(new Set(activities.map((a) => a.category)))
  const categoryTotals = categories.map((c) => {
    const list = activities.filter((a) => a.category === c)
    return {
      category: c,
      count: list.length,
      income: list.reduce((sum, a) => sum + a.income, 0),
    }
  })

  return (
    <div className="pb-6">
      <PageHeader title="Livelihood Activities" subtitle="Income generating activities" />

      <div className="px-4 mt-2 grid grid-cols-2 gap-3">
        <StatCard label="Total Income" value={`₹${totalIncome.toLocaleString('en-IN')}`} tone="brand" trend="This month" icon={<TrendingUp className="h-4 w-4" />} />
        <StatCard label="Total Expense" value={`₹${totalExpense.toLocaleString('en-IN')}`} tone="gold" trend={`${activities.length} activities`} icon={<Wallet className="h-4 w-4" />} />
      </div>

      <div className="px-4 mt-5 grid grid-cols-4 gap-2">
        <IconTile to={paths.livelihoodEntry} icon={<PlusCircle className="h-5.5 w-5.5" />} label="New Entry" tone="brand" />
        <IconTile to={paths.marketplace} icon={<Sprout className="h-5.5 w-5.5" />} label="Marketplace" tone="gold" />
      </div>

      <div className="px-4 mt-6">
        <SectionHeader title="By Category" subtitle="Income generated this month" />
        <div className="grid grid-cols-2 gap-3">
          {categoryTotals.map((c) => {
            const meta = categoryMeta[c.category]
            return (
              <Card key={c.category} className="flex items-center gap-3">
                <div className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-xl text-lg ${meta.color}`}>
                  {meta.icon}
                </div>
                <div className="min-w-0">
                  <p className="text-xs font-semibold text-ink-800 truncate">{c.category}</p>
                  <p className="text-[11px] text-ink-500">{c.count} · ₹{c.income.toLocaleString('en-IN')}</p>
                </div>
              </Card>
            )
          })}
        </div>
      </div>

      <div className="px-4 mt-6">
        <SectionHeader title="Recent Activities" action="Add entry" actionTo={paths.livelihoodEntry} />
        <div className="space-y-3">
          {activities.map((a) => {
            const meta = categoryMeta[a.category]
            const net = a.income - a.expense
            return (
              <Link key={a.id} to={paths.livelihoodDetail(a.id)}>
                <Card interactive>
                  <div className="flex items-start justify-between">
                    <div className="flex items-center gap-3 min-w-0">
                      <div className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-xl text-lg ${meta.color}`}>
                        {meta.icon}
                      </div>
                      <div className="min-w-0">
                        <p className="text-sm font-bold text-ink-900 truncate">{a.member}</p>
                        <p className="text-xs text-ink-500 mt-0.5 truncate">{a.production}</p>
                      </div>
                    </div>
                    <Badge tone="brand">{a.category}</Badge>
                  </div>
                  <div className="flex items-end justify-between mt-3">
                    <div>
                      <p className="text-base font-bold font-display text-ink-900">₹{net.toLocaleString('en-IN')}</p>
                      <p className="text-xs text-ink-500">net income</p>
                    </div>
                    <p className="text-xs text-ink-500">{a.month}</p>
                  </div>
                </Card>
              </Link>
            )
          })}
        </div>
      </div>
    </div>
  )
}
