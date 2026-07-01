import { Link, useLocation } from 'react-router-dom'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Badge } from '../../components/ui/Badge'
import { cashBook } from '../../data/financial'
import { paths } from '../../routes/paths'

const tabs = [
  { to: paths.financialCashbook, label: 'Cash Book' },
  { to: paths.financialLedger, label: 'Ledger' },
  { to: paths.financialBank, label: 'Bank' },
  { to: paths.financialAudit, label: 'Audit' },
]

export function FinanceTabs() {
  const { pathname } = useLocation()
  return (
    <div className="flex gap-2 overflow-x-auto no-scrollbar px-4 pb-1">
      {tabs.map((t) => (
        <Link
          key={t.to}
          to={t.to}
          className={`shrink-0 rounded-full px-4 py-2 text-xs font-semibold transition ${
            pathname === t.to ? 'bg-brand-600 text-white' : 'bg-ink-100 text-ink-600'
          }`}
        >
          {t.label}
        </Link>
      ))}
    </div>
  )
}

export function CashBook() {
  const balance = cashBook[0]?.balance ?? 0
  return (
    <div className="pb-6">
      <PageHeader title="Financial Records" subtitle={`Cash-in-hand ₹${balance.toLocaleString('en-IN')}`} />
      <div className="mt-2"><FinanceTabs /></div>
      <div className="px-4 mt-4">
        <Card className="!p-0 divide-y divide-ink-100">
          {cashBook.map((c) => (
            <div key={c.id} className="flex items-center justify-between px-4 py-3">
              <div className="min-w-0">
                <p className="text-xs font-semibold text-ink-800 truncate">{c.particulars}</p>
                <p className="text-[11px] text-ink-400">{c.date}</p>
              </div>
              <div className="text-right shrink-0">
                <p className={`text-sm font-bold ${c.type === 'receipt' ? 'text-brand-700' : 'text-red-500'}`}>
                  {c.type === 'receipt' ? '+' : '-'}₹{c.amount.toLocaleString('en-IN')}
                </p>
                <Badge tone="neutral">Bal ₹{c.balance.toLocaleString('en-IN')}</Badge>
              </div>
            </div>
          ))}
        </Card>
      </div>
    </div>
  )
}
