import { Check, X } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Badge } from '../../components/ui/Badge'
import { EmptyState } from '../../components/ui/EmptyState'
import { useData } from '../../context/DataContext'
import { cn } from '../../lib/cn'

type Status = 'applied' | 'under_review' | 'approved' | 'rejected'

const statusTone: Record<Status, 'success' | 'warning' | 'info' | 'danger'> = {
  approved: 'success',
  under_review: 'warning',
  applied: 'info',
  rejected: 'danger',
}

const statusLabel: Record<Status, string> = {
  approved: 'Approved',
  under_review: 'Under Review',
  applied: 'Applied',
  rejected: 'Rejected',
}

const steps: { key: Status; label: string }[] = [
  { key: 'applied', label: 'Applied' },
  { key: 'under_review', label: 'Under Review' },
  { key: 'approved', label: 'Approved / Rejected' },
]

function stepIndex(status: Status) {
  if (status === 'applied') return 0
  if (status === 'under_review') return 1
  return 2
}

export function ApplicationTracking() {
  const { schemes } = useData()
  const tracked = schemes.filter((s) => s.status && s.status !== 'not_applied') as (typeof schemes[number] & { status: Status })[]

  if (tracked.length === 0) {
    return (
      <div className="pb-6">
        <PageHeader title="Application Tracking" />
        <div className="px-4 pt-8">
          <EmptyState title="No applications yet" description="Applications you submit for government schemes will appear here." />
        </div>
      </div>
    )
  }

  return (
    <div className="pb-6">
      <PageHeader title="Application Tracking" subtitle={`${tracked.length} applications`} />

      <div className="px-4 mt-2 space-y-4">
        {tracked.map((s) => {
          const current = stepIndex(s.status)
          const rejected = s.status === 'rejected'
          return (
            <Card key={s.id}>
              <div className="flex items-start justify-between gap-2">
                <div className="min-w-0">
                  <Badge tone="brand">{s.name}</Badge>
                  <p className="text-sm font-semibold text-ink-900 mt-1.5 truncate">{s.fullName}</p>
                </div>
                <Badge tone={statusTone[s.status]} className="shrink-0">{statusLabel[s.status]}</Badge>
              </div>

              <div className="mt-4 space-y-0">
                {steps.map((step, i) => {
                  const done = i < current || (i === current)
                  const isLast = i === steps.length - 1
                  const isFinalRejected = isLast && rejected
                  return (
                    <div key={step.key} className="flex gap-3">
                      <div className="flex flex-col items-center">
                        <div
                          className={cn(
                            'flex h-6 w-6 shrink-0 items-center justify-center rounded-full',
                            isFinalRejected
                              ? 'bg-red-500 text-white'
                              : done
                                ? 'bg-brand-600 text-white'
                                : 'bg-ink-100 text-ink-400',
                          )}
                        >
                          {isFinalRejected ? <X className="h-3.5 w-3.5" /> : <Check className="h-3.5 w-3.5" />}
                        </div>
                        {!isLast && <div className={cn('w-0.5 flex-1 min-h-6', i < current ? 'bg-brand-600' : 'bg-ink-100')} />}
                      </div>
                      <div className={cn('pb-4', isLast && 'pb-0')}>
                        <p className={cn('text-xs font-semibold', done ? 'text-ink-900' : 'text-ink-400')}>
                          {isFinalRejected ? 'Rejected' : step.label}
                        </p>
                      </div>
                    </div>
                  )
                })}
              </div>

              {s.deadline && <p className="text-[11px] text-gold-700 mt-1 font-semibold">Deadline: {s.deadline}</p>}
            </Card>
          )
        })}
      </div>
    </div>
  )
}
