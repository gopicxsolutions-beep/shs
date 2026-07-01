import { Link } from 'react-router-dom'
import { AlertTriangle } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Badge } from '../../components/ui/Badge'
import { Avatar } from '../../components/ui/Avatar'
import { ProgressBar } from '../../components/ui/ProgressBar'
import { paths } from '../../routes/paths'
import { loans } from '../../data/loans'

const statusTone: Record<string, 'success' | 'warning' | 'danger' | 'brand' | 'neutral'> = {
  active: 'brand', pending: 'warning', overdue: 'danger', closed: 'success', approved: 'success', rejected: 'neutral',
}

export function LoanTracking() {
  const overdue = loans.filter((l) => l.status === 'overdue')
  const tracked = loans.filter((l) => l.status === 'active' || l.status === 'overdue')

  return (
    <div className="pb-6">
      <PageHeader title="Loan Tracking" subtitle={`${tracked.length} loans being tracked`} />

      {overdue.length > 0 && (
        <div className="px-4 mt-2">
          <Card className="flex items-center gap-3 bg-red-50 border-red-100">
            <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-red-100 text-red-600">
              <AlertTriangle className="h-5 w-5" />
            </div>
            <div className="min-w-0">
              <p className="text-sm font-bold text-red-700">Defaulter Alert</p>
              <p className="text-xs text-red-500">{overdue.map((l) => l.memberName).join(', ')} — EMI overdue</p>
            </div>
          </Card>
        </div>
      )}

      <div className="px-4 mt-4 space-y-3">
        {tracked.map((l) => (
          <Link key={l.id} to={paths.loanDetail(l.id)}>
            <Card interactive className="flex items-center gap-3">
              <Avatar name={l.memberName} size="sm" />
              <div className="min-w-0 flex-1">
                <div className="flex items-center justify-between">
                  <p className="text-xs font-semibold text-ink-800 truncate">{l.memberName}</p>
                  <Badge tone={statusTone[l.status]}>{l.status}</Badge>
                </div>
                <div className="flex items-center justify-between mt-1">
                  <ProgressBar value={l.amount - l.outstanding} max={l.amount} tone={l.status === 'overdue' ? 'danger' : 'gold'} className="flex-1 mr-2" />
                  <span className="text-[11px] text-ink-500 shrink-0">₹{l.outstanding.toLocaleString('en-IN')}</span>
                </div>
                <p className="text-[11px] text-ink-400 mt-1">Next EMI ₹{l.emi} · {l.nextDueDate}</p>
              </div>
            </Card>
          </Link>
        ))}
      </div>
    </div>
  )
}
