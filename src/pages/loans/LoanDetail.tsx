import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { CheckCircle2 } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Badge } from '../../components/ui/Badge'
import { ProgressBar } from '../../components/ui/ProgressBar'
import { Button } from '../../components/ui/Button'
import { EmptyState } from '../../components/ui/EmptyState'
import { paths } from '../../routes/paths'
import { loans } from '../../data/loans'

const statusTone: Record<string, 'success' | 'warning' | 'danger' | 'brand' | 'neutral'> = {
  active: 'brand', pending: 'warning', overdue: 'danger', closed: 'success', approved: 'success', rejected: 'neutral',
}

export function LoanDetail() {
  const { id } = useParams()
  const navigate = useNavigate()
  const loan = loans.find((l) => l.id === id)
  const [paid, setPaid] = useState(false)

  if (paid && loan) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center px-8 text-center">
        <div className="flex h-16 w-16 items-center justify-center rounded-full bg-brand-50 text-brand-600">
          <CheckCircle2 className="h-9 w-9" />
        </div>
        <h1 className="mt-5 font-display text-xl font-bold text-ink-900">EMI paid successfully!</h1>
        <p className="mt-1.5 text-sm text-ink-500">₹{loan.emi} received. Digital receipt sent by SMS &amp; the loan ledger has been updated.</p>
        <Card className="mt-6 w-full text-left">
          <div className="flex items-center justify-between text-xs">
            <span className="text-ink-500">Receipt No.</span>
            <span className="font-semibold text-ink-800">RCPT-{loan.id.toUpperCase()}-{Math.floor(Math.random() * 9000 + 1000)}</span>
          </div>
          <div className="flex items-center justify-between text-xs mt-2">
            <span className="text-ink-500">New outstanding</span>
            <span className="font-semibold text-ink-800">₹{Math.max(0, loan.outstanding - loan.emi).toLocaleString('en-IN')}</span>
          </div>
        </Card>
        <Button className="mt-8" fullWidth size="lg" onClick={() => navigate(paths.loanTracking)}>
          Done
        </Button>
      </div>
    )
  }

  if (!loan) {
    return (
      <div>
        <PageHeader title="Loan" />
        <div className="px-4 pt-8"><EmptyState title="Loan not found" /></div>
      </div>
    )
  }

  const paidInstallments = Math.round(((loan.amount - loan.outstanding) / loan.amount) * loan.tenureMonths)
  const schedule = Array.from({ length: loan.tenureMonths }, (_, i) => ({
    n: i + 1,
    paid: i < paidInstallments,
    amount: loan.emi || Math.round(loan.amount / loan.tenureMonths),
  }))

  return (
    <div className="pb-6">
      <PageHeader title="Loan Details" subtitle={loan.memberName} />
      <div className="px-4 mt-2">
        <Card>
          <div className="flex items-start justify-between">
            <div>
              <p className="text-xs text-ink-500">{loan.purpose}</p>
              <p className="text-2xl font-bold font-display text-ink-900 mt-1">₹{loan.outstanding.toLocaleString('en-IN')}</p>
              <p className="text-xs text-ink-500">outstanding of ₹{loan.amount.toLocaleString('en-IN')}</p>
            </div>
            <Badge tone={statusTone[loan.status]}>{loan.status}</Badge>
          </div>
          <ProgressBar value={loan.amount - loan.outstanding} max={loan.amount} tone={loan.status === 'overdue' ? 'danger' : 'gold'} className="mt-3" />
          <div className="grid grid-cols-3 gap-2 mt-4 text-center">
            <div>
              <p className="text-sm font-bold text-ink-900">₹{loan.emi || '—'}</p>
              <p className="text-[10px] text-ink-500">EMI</p>
            </div>
            <div className="border-x border-ink-100">
              <p className="text-sm font-bold text-ink-900">{loan.tenureMonths}mo</p>
              <p className="text-[10px] text-ink-500">Tenure</p>
            </div>
            <div>
              <p className="text-sm font-bold text-ink-900">{loan.disbursedOn || 'Pending'}</p>
              <p className="text-[10px] text-ink-500">Disbursed</p>
            </div>
          </div>
        </Card>
      </div>

      {loan.status !== 'pending' && (
        <div className="px-4 mt-5">
          <h2 className="text-[15px] font-bold text-ink-900 font-display mb-3">EMI Schedule</h2>
          <Card className="!p-0 divide-y divide-ink-100 max-h-72 overflow-y-auto">
            {schedule.map((s) => (
              <div key={s.n} className="flex items-center justify-between px-4 py-2.5">
                <span className="text-xs text-ink-600">Installment {s.n}</span>
                <span className="text-xs font-semibold text-ink-800">₹{s.amount.toLocaleString('en-IN')}</span>
                <Badge tone={s.paid ? 'success' : 'neutral'}>{s.paid ? 'Paid' : 'Due'}</Badge>
              </div>
            ))}
          </Card>
        </div>
      )}

      {loan.status === 'active' || loan.status === 'overdue' ? (
        <div className="px-4 mt-5">
          <Button fullWidth size="lg" onClick={() => setPaid(true)}>Pay EMI ₹{loan.emi}</Button>
        </div>
      ) : null}
    </div>
  )
}
