import { Download, Share2 } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
import { useApp } from '../../context/AppContext'
import { useData } from '../../context/DataContext'

export function SavingsStatement() {
  const { user } = useApp()
  const { savingsEntries } = useData()
  const mine = savingsEntries.filter((s) => s.memberName === 'Lakshmi Devi')
  const total = mine.reduce((s, e) => s + e.amount, 0)

  return (
    <div className="pb-6">
      <PageHeader title="Savings Statement" />
      <div className="px-4 mt-2">
        <Card>
          <div className="flex items-center justify-between border-b border-dashed border-ink-200 pb-3">
            <div>
              <p className="text-sm font-bold text-ink-900">{user.name}</p>
              <p className="text-xs text-ink-500">{user.shgName}</p>
            </div>
            <p className="text-xs text-ink-400">01 Jan – 28 Jun 2026</p>
          </div>
          <div className="flex items-center justify-between py-3">
            <span className="text-xs text-ink-500">Total Savings (period)</span>
            <span className="text-lg font-bold font-display text-brand-700">₹{total.toLocaleString('en-IN')}</span>
          </div>
          <div className="space-y-2">
            {mine.map((e) => (
              <div key={e.id} className="flex items-center justify-between text-xs">
                <span className="text-ink-500">{e.date} · {e.mode}</span>
                <span className="font-semibold text-ink-800">+₹{e.amount}</span>
              </div>
            ))}
          </div>
        </Card>

        <div className="mt-4 grid grid-cols-2 gap-3">
          <Button variant="outline" icon={<Download className="h-4 w-4" />}>Download</Button>
          <Button variant="secondary" icon={<Share2 className="h-4 w-4" />}>Share</Button>
        </div>
      </div>
    </div>
  )
}
