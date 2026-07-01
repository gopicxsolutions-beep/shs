import { Landmark, ArrowDownLeft, ArrowUpRight } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { FinanceTabs } from './CashBook'
import { bankAccount } from '../../data/financial'
import { shgInfo as info } from '../../data/shg'

export function BankAccount() {
  return (
    <div className="pb-6">
      <PageHeader title="Bank Account" />
      <div className="mt-2"><FinanceTabs /></div>

      <div className="px-4 mt-4">
        <Card className="bg-gradient-to-br from-ink-900 to-ink-700 text-white">
          <div className="flex items-center gap-2 text-white/70">
            <Landmark className="h-4 w-4" />
            <span className="text-xs">{info.bankName}</span>
          </div>
          <p className="text-2xl font-bold font-display mt-3">₹{bankAccount.balance.toLocaleString('en-IN')}</p>
          <p className="text-xs text-white/60 mt-1">A/C {info.bankAccount} · IFSC {info.ifsc}</p>
          <p className="text-[11px] text-white/50 mt-3">Last updated {bankAccount.lastTransactionDate}</p>
        </Card>
      </div>

      <div className="px-4 mt-5">
        <h2 className="text-[15px] font-bold text-ink-900 font-display mb-3">Recent Transactions</h2>
        <Card className="!p-0 divide-y divide-ink-100">
          {bankAccount.transactions.map((t) => (
            <div key={t.id} className="flex items-center gap-3 px-4 py-3">
              <div className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-full ${t.amount > 0 ? 'bg-brand-50 text-brand-600' : 'bg-red-50 text-red-500'}`}>
                {t.amount > 0 ? <ArrowDownLeft className="h-4 w-4" /> : <ArrowUpRight className="h-4 w-4" />}
              </div>
              <div className="min-w-0 flex-1">
                <p className="text-xs font-semibold text-ink-800 truncate">{t.desc}</p>
                <p className="text-[11px] text-ink-400">{t.date}</p>
              </div>
              <p className={`text-sm font-bold shrink-0 ${t.amount > 0 ? 'text-brand-700' : 'text-red-500'}`}>
                {t.amount > 0 ? '+' : ''}₹{Math.abs(t.amount).toLocaleString('en-IN')}
              </p>
            </div>
          ))}
        </Card>
      </div>
    </div>
  )
}
