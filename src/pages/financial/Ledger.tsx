import { useState } from 'react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { SegmentedTabs } from '../../components/ui/SegmentedTabs'
import { Avatar } from '../../components/ui/Avatar'
import { FinanceTabs } from './CashBook'
import { cashBook } from '../../data/financial'
import { members } from '../../data/members'

export function Ledger() {
  const [view, setView] = useState('general')

  return (
    <div className="pb-6">
      <PageHeader title="Ledger" />
      <div className="mt-2"><FinanceTabs /></div>
      <div className="px-4 mt-3">
        <SegmentedTabs
          options={[
            { value: 'general', label: 'General Ledger' },
            { value: 'member', label: 'Member Ledger' },
          ]}
          value={view}
          onChange={setView}
        />
      </div>

      {view === 'general' ? (
        <div className="px-4 mt-4">
          <Card className="!p-0 divide-y divide-ink-100">
            {cashBook.map((c) => (
              <div key={c.id} className="flex items-center justify-between px-4 py-3">
                <div className="min-w-0">
                  <p className="text-xs font-semibold text-ink-800 truncate">{c.particulars}</p>
                  <p className="text-[11px] text-ink-400">{c.date} · {c.type === 'receipt' ? 'Receipt' : 'Payment'}</p>
                </div>
                <p className={`text-sm font-bold shrink-0 ${c.type === 'receipt' ? 'text-brand-700' : 'text-red-500'}`}>
                  {c.type === 'receipt' ? '+' : '-'}₹{c.amount.toLocaleString('en-IN')}
                </p>
              </div>
            ))}
          </Card>
        </div>
      ) : (
        <div className="px-4 mt-4">
          <Card className="!p-0 divide-y divide-ink-100">
            {members.map((m) => (
              <div key={m.id} className="flex items-center gap-3 px-4 py-3">
                <Avatar name={m.name} size="sm" />
                <div className="min-w-0 flex-1">
                  <p className="text-xs font-semibold text-ink-800 truncate">{m.name}</p>
                  <p className="text-[11px] text-ink-400">Savings ₹{m.savings.toLocaleString('en-IN')}</p>
                </div>
                <p className="text-xs font-bold text-gold-600 shrink-0">
                  {m.loanOutstanding > 0 ? `-₹${m.loanOutstanding.toLocaleString('en-IN')}` : '—'}
                </p>
              </div>
            ))}
          </Card>
        </div>
      )}
    </div>
  )
}
