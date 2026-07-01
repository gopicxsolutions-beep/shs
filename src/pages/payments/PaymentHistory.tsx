import { useState } from 'react'
import { ArrowUpRight, ArrowDownLeft } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { SegmentedTabs } from '../../components/ui/SegmentedTabs'
import { EmptyState } from '../../components/ui/EmptyState'
import { recentTransactions } from './transactions'

const tabs = [
  { value: 'All', label: 'All' },
  { value: 'Savings', label: 'Savings' },
  { value: 'Loan EMI', label: 'Loan' },
]

export function PaymentHistory() {
  const [tab, setTab] = useState('All')
  const filtered = tab === 'All' ? recentTransactions : recentTransactions.filter((t) => t.type === tab)

  return (
    <div className="pb-6">
      <PageHeader title="Payment History" subtitle={`${recentTransactions.length} UPI transactions`} />

      <div className="px-4 mt-2">
        <SegmentedTabs options={tabs} value={tab} onChange={setTab} />
      </div>

      <div className="px-4 mt-4">
        {filtered.length === 0 ? (
          <EmptyState title="No transactions" description="No payments found for this filter." />
        ) : (
          <Card className="!p-0 divide-y divide-ink-100">
            {filtered.map((t) => {
              const isCredit = t.type === 'Savings'
              return (
                <div key={t.id} className="flex items-center gap-3 px-4 py-3">
                  <div className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-xl ${isCredit ? 'bg-brand-50 text-brand-600' : 'bg-red-50 text-red-500'}`}>
                    {isCredit ? <ArrowDownLeft className="h-4 w-4" /> : <ArrowUpRight className="h-4 w-4" />}
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="text-xs font-semibold text-ink-800 truncate">{t.member}</p>
                    <p className="text-[11px] text-ink-400 mt-0.5">{t.type} · {t.date}</p>
                    <p className="text-[10px] text-ink-300 mt-0.5 truncate">Ref: {t.txnId}</p>
                  </div>
                  <p className={`text-sm font-bold shrink-0 ${isCredit ? 'text-brand-600' : 'text-red-500'}`}>
                    {isCredit ? '+' : '-'}₹{t.amount.toLocaleString('en-IN')}
                  </p>
                </div>
              )
            })}
          </Card>
        )}
      </div>
    </div>
  )
}
