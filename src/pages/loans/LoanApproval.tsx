import { useState } from 'react'
import { Check, X } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
import { Avatar } from '../../components/ui/Avatar'
import { Badge } from '../../components/ui/Badge'
import { EmptyState } from '../../components/ui/EmptyState'
import { loans as loanData } from '../../data/loans'

export function LoanApproval() {
  const [decided, setDecided] = useState<Record<string, 'approved' | 'rejected'>>({})
  const pending = loanData.filter((l) => l.status === 'pending')

  return (
    <div className="pb-6">
      <PageHeader title="Loan Approvals" subtitle={`${pending.length} pending requests`} />
      <div className="px-4 mt-2 space-y-3">
        {pending.length === 0 && <EmptyState title="No pending requests" description="All loan applications have been reviewed." />}
        {pending.map((l) => {
          const decision = decided[l.id]
          return (
            <Card key={l.id}>
              <div className="flex items-center gap-3">
                <Avatar name={l.memberName} />
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-bold text-ink-900 truncate">{l.memberName}</p>
                  <p className="text-xs text-ink-500 truncate">{l.purpose}</p>
                </div>
                <p className="text-sm font-bold font-display text-ink-900 shrink-0">₹{l.amount.toLocaleString('en-IN')}</p>
              </div>
              <div className="flex items-center justify-between mt-3 text-xs text-ink-500">
                <span>Tenure: {l.tenureMonths} months</span>
                <span>Est. EMI: ₹{Math.round(l.amount / l.tenureMonths).toLocaleString('en-IN')}</span>
              </div>

              {decision ? (
                <Badge tone={decision === 'approved' ? 'success' : 'danger'} className="mt-3">
                  {decision === 'approved' ? 'Approved' : 'Rejected'}
                </Badge>
              ) : (
                <div className="mt-3 grid grid-cols-2 gap-2">
                  <Button
                    variant="danger"
                    size="sm"
                    icon={<X className="h-3.5 w-3.5" />}
                    onClick={() => setDecided((d) => ({ ...d, [l.id]: 'rejected' }))}
                  >
                    Reject
                  </Button>
                  <Button
                    size="sm"
                    icon={<Check className="h-3.5 w-3.5" />}
                    onClick={() => setDecided((d) => ({ ...d, [l.id]: 'approved' }))}
                  >
                    Approve
                  </Button>
                </div>
              )}
            </Card>
          )
        })}
      </div>
    </div>
  )
}
