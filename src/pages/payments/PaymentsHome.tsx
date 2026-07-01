import { Link } from 'react-router-dom'
import { QrCode, History, Wallet, Landmark, ArrowUpRight, ArrowDownLeft } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Badge } from '../../components/ui/Badge'
import { IconTile } from '../../components/ui/IconTile'
import { SectionHeader } from '../../components/ui/SectionHeader'
import { paths } from '../../routes/paths'
import { recentTransactions } from './transactions'

export function PaymentsHome() {
  const recent = recentTransactions.slice(0, 4)

  return (
    <div className="pb-6">
      <PageHeader title="Digital Payments" subtitle="UPI-powered SHG payments" />

      <div className="px-4 mt-2">
        <Card className="relative overflow-hidden bg-gradient-to-br from-brand-600 to-brand-800 text-white !p-5">
          <div className="absolute -right-6 -top-8 h-28 w-28 rounded-full bg-white/10" />
          <div className="absolute -right-10 bottom-0 h-20 w-20 rounded-full bg-white/10" />
          <div className="relative">
            <p className="text-xs font-medium text-white/75">This Month's UPI Activity</p>
            <p className="mt-1.5 text-2xl font-bold font-display">₹{recentTransactions.reduce((s, t) => s + t.amount, 0).toLocaleString('en-IN')}</p>
            <p className="mt-1 text-[11px] text-white/70">{recentTransactions.length} transactions via UPI</p>
          </div>
        </Card>
      </div>

      <div className="px-4 mt-5 grid grid-cols-2 gap-2">
        <IconTile to={paths.paymentsQr} icon={<QrCode className="h-5.5 w-5.5" />} label="Scan & Pay" tone="brand" />
        <IconTile to={paths.paymentsHistory} icon={<History className="h-5.5 w-5.5" />} label="History" tone="gold" />
      </div>

      <div className="px-4 mt-6">
        <SectionHeader title="Quick Actions" />
        <div className="grid grid-cols-2 gap-3">
          <Link to={paths.savingsEntry}>
            <Card interactive className="flex flex-col gap-2">
              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-brand-50 text-brand-600">
                <Wallet className="h-5 w-5" />
              </div>
              <p className="text-xs font-semibold text-ink-900">Collect Savings</p>
              <p className="text-[11px] text-ink-500">Record member savings via UPI</p>
            </Card>
          </Link>
          <Link to={paths.loanTracking}>
            <Card interactive className="flex flex-col gap-2">
              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-gold-50 text-gold-600">
                <Landmark className="h-5 w-5" />
              </div>
              <p className="text-xs font-semibold text-ink-900">Pay Loan EMI</p>
              <p className="text-[11px] text-ink-500">Settle EMI dues instantly</p>
            </Card>
          </Link>
        </div>
      </div>

      <div className="px-4 mt-6">
        <SectionHeader title="Recent Transactions" action="View all" actionTo={paths.paymentsHistory} />
        <Card className="!p-0 divide-y divide-ink-100">
          {recent.map((t) => (
            <div key={t.id} className="flex items-center gap-3 px-4 py-3">
              <div className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-xl ${t.type === 'Savings' ? 'bg-brand-50 text-brand-600' : 'bg-gold-50 text-gold-600'}`}>
                {t.type === 'Savings' ? <ArrowDownLeft className="h-4 w-4" /> : <ArrowUpRight className="h-4 w-4" />}
              </div>
              <div className="min-w-0 flex-1">
                <p className="text-xs font-semibold text-ink-800 truncate">{t.member}</p>
                <p className="text-[11px] text-ink-400 mt-0.5">{t.type} · {t.date}</p>
              </div>
              <div className="text-right shrink-0">
                <p className={`text-sm font-bold ${t.type === 'Savings' ? 'text-brand-600' : 'text-red-500'}`}>
                  {t.type === 'Savings' ? '+' : '-'}₹{t.amount.toLocaleString('en-IN')}
                </p>
                <Badge tone="neutral" className="mt-1">UPI</Badge>
              </div>
            </div>
          ))}
        </Card>
      </div>
    </div>
  )
}
