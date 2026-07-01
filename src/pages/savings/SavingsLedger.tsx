import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { useData } from '../../context/DataContext'

export function SavingsLedger() {
  const { savingsEntries } = useData()
  let running = 486200 - savingsEntries.reduce((s, e) => s + e.amount, 0)
  const rows = savingsEntries
    .slice()
    .reverse()
    .map((e) => {
      running += e.amount
      return { ...e, balance: running }
    })
    .reverse()

  return (
    <div className="pb-6">
      <PageHeader title="Savings Ledger" subtitle="Group-wise running balance" />
      <div className="px-4 mt-2">
        <Card className="!p-0 overflow-hidden">
          <div className="grid grid-cols-[1fr_auto_auto] gap-2 bg-ink-50 px-4 py-2.5 text-[10px] font-bold uppercase tracking-wide text-ink-400">
            <span>Member / Date</span>
            <span className="text-right">Amount</span>
            <span className="text-right">Balance</span>
          </div>
          <div className="divide-y divide-ink-100">
            {rows.map((r) => (
              <div key={r.id} className="grid grid-cols-[1fr_auto_auto] gap-2 px-4 py-3">
                <div className="min-w-0">
                  <p className="text-xs font-semibold text-ink-800 truncate">{r.memberName}</p>
                  <p className="text-[10px] text-ink-400">{r.date}</p>
                </div>
                <span className="self-center text-right text-xs font-semibold text-brand-700">+₹{r.amount}</span>
                <span className="self-center text-right text-xs font-bold text-ink-900">₹{r.balance.toLocaleString('en-IN')}</span>
              </div>
            ))}
          </div>
        </Card>
      </div>
    </div>
  )
}
