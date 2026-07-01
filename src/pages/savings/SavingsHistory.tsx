import { useState } from 'react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Badge } from '../../components/ui/Badge'
import { SegmentedTabs } from '../../components/ui/SegmentedTabs'
import { Avatar } from '../../components/ui/Avatar'
import { useData } from '../../context/DataContext'

export function SavingsHistory() {
  const { savingsEntries } = useData()
  const [filter, setFilter] = useState('all')
  const filtered = filter === 'all' ? savingsEntries : savingsEntries.filter((s) => s.status === filter)

  return (
    <div className="pb-6">
      <PageHeader title="Savings History" subtitle={`${savingsEntries.length} entries`} />
      <div className="px-4 pt-2">
        <SegmentedTabs
          options={[
            { value: 'all', label: 'All' },
            { value: 'verified', label: 'Verified' },
            { value: 'pending', label: 'Pending' },
          ]}
          value={filter}
          onChange={setFilter}
        />
      </div>
      <div className="px-4 mt-4">
        <Card className="!p-0 divide-y divide-ink-100">
          {filtered.map((s) => (
            <div key={s.id} className="flex items-center gap-3 px-4 py-3">
              <Avatar name={s.memberName} size="sm" />
              <div className="min-w-0 flex-1">
                <p className="text-xs font-semibold text-ink-800 truncate">{s.memberName}</p>
                <p className="text-[11px] text-ink-400">{s.date} · {s.mode} · {s.type}</p>
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
