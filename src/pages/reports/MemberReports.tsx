import { useState } from 'react'
import { ChevronDown } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Avatar } from '../../components/ui/Avatar'
import { Badge } from '../../components/ui/Badge'
import { ProgressBar } from '../../components/ui/ProgressBar'
import { cn } from '../../lib/cn'
import { members } from '../../data/members'

export function MemberReports() {
  const [expandedId, setExpandedId] = useState<string | null>(members[0]?.id ?? null)

  return (
    <div className="pb-6">
      <PageHeader title="Member Reports" subtitle="Savings, loan & attendance statements" />

      <div className="px-4 mt-2 space-y-3">
        {members.map((m) => {
          const open = expandedId === m.id
          return (
            <Card key={m.id} className="!p-0 overflow-hidden">
              <button
                onClick={() => setExpandedId(open ? null : m.id)}
                className="flex w-full items-center gap-3 px-4 py-3.5 text-left"
              >
                <Avatar name={m.name} size="sm" />
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-semibold text-ink-900 truncate">{m.name}</p>
                  <p className="text-[11px] text-ink-400">{m.role} · Joined {m.joiningDate}</p>
                </div>
                <Badge tone={m.status === 'active' ? 'success' : 'neutral'}>{m.status}</Badge>
                <ChevronDown className={cn('h-4 w-4 shrink-0 text-ink-400 transition-transform', open && 'rotate-180')} />
              </button>

              {open && (
                <div className="px-4 pb-4 space-y-3">
                  <div className="grid grid-cols-2 gap-2.5">
                    <div className="rounded-xl bg-brand-50 p-3">
                      <p className="text-[11px] text-brand-700 font-medium">Savings Statement</p>
                      <p className="text-base font-bold font-display text-ink-900 mt-1">₹{m.savings.toLocaleString('en-IN')}</p>
                    </div>
                    <div className="rounded-xl bg-gold-50 p-3">
                      <p className="text-[11px] text-gold-700 font-medium">Loan Statement</p>
                      <p className="text-base font-bold font-display text-ink-900 mt-1">
                        {m.loanOutstanding > 0 ? `₹${m.loanOutstanding.toLocaleString('en-IN')}` : 'No active loan'}
                      </p>
                    </div>
                  </div>

                  <div>
                    <div className="flex items-center justify-between mb-1">
                      <p className="text-[11px] font-medium text-ink-500">Attendance Report</p>
                      <p className="text-xs font-semibold text-ink-700">{m.attendance}%</p>
                    </div>
                    <ProgressBar value={m.attendance} tone={m.attendance >= 85 ? 'brand' : m.attendance >= 70 ? 'gold' : 'danger'} />
                  </div>

                  <div className="flex items-center justify-between text-[11px] text-ink-400">
                    <span>Mobile: {m.mobile}</span>
                    <span>Aadhaar: {m.aadhaar}</span>
                  </div>
                </div>
              )}
            </Card>
          )
        })}
      </div>
    </div>
  )
}
