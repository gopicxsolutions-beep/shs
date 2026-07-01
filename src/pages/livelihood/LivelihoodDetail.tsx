import { useParams } from 'react-router-dom'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Badge } from '../../components/ui/Badge'
import { Avatar } from '../../components/ui/Avatar'
import { EmptyState } from '../../components/ui/EmptyState'
import { activities, categoryMeta } from '../../data/livelihood'

export function LivelihoodDetail() {
  const { id } = useParams()
  const activity = activities.find((a) => a.id === id)

  if (!activity) {
    return (
      <div>
        <PageHeader title="Activity" />
        <div className="px-4 pt-8"><EmptyState title="Activity not found" /></div>
      </div>
    )
  }

  const meta = categoryMeta[activity.category]
  const net = activity.income - activity.expense

  return (
    <div className="pb-6">
      <PageHeader title="Activity Details" subtitle={activity.member} />

      <div className="px-4 mt-2">
        <Card>
          <div className="flex items-start justify-between">
            <div className="flex items-center gap-3">
              <Avatar name={activity.member} size="lg" />
              <div>
                <p className="text-sm font-bold text-ink-900">{activity.member}</p>
                <p className="text-xs text-ink-500 mt-0.5">{activity.month}</p>
              </div>
            </div>
            <Badge tone="brand">{activity.category}</Badge>
          </div>

          <div className="mt-4 flex items-center gap-3 rounded-xl bg-ink-50 p-3">
            <div className={`flex h-11 w-11 shrink-0 items-center justify-center rounded-xl text-xl ${meta.color}`}>
              {meta.icon}
            </div>
            <div className="min-w-0">
              <p className="text-xs text-ink-500">Production</p>
              <p className="text-sm font-semibold text-ink-900 truncate">{activity.production}</p>
            </div>
          </div>

          <div className="grid grid-cols-3 gap-2 mt-4 text-center">
            <div>
              <p className="text-sm font-bold text-brand-700">₹{activity.income.toLocaleString('en-IN')}</p>
              <p className="text-[10px] text-ink-500">Income</p>
            </div>
            <div className="border-x border-ink-100">
              <p className="text-sm font-bold text-ink-900">₹{activity.expense.toLocaleString('en-IN')}</p>
              <p className="text-[10px] text-ink-500">Expense</p>
            </div>
            <div>
              <p className="text-sm font-bold font-display text-ink-900">₹{net.toLocaleString('en-IN')}</p>
              <p className="text-[10px] text-ink-500">Net</p>
            </div>
          </div>
        </Card>
      </div>
    </div>
  )
}
