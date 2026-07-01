import { Link } from 'react-router-dom'
import { PlusCircle, ClipboardCheck, Radar, Landmark } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { StatCard } from '../../components/ui/StatCard'
import { SectionHeader } from '../../components/ui/SectionHeader'
import { Badge } from '../../components/ui/Badge'
import { ProgressBar } from '../../components/ui/ProgressBar'
import { IconTile } from '../../components/ui/IconTile'
import { paths } from '../../routes/paths'
import { loans } from '../../data/loans'
import { shgInfo } from '../../data/shg'

const statusTone: Record<string, 'success' | 'warning' | 'danger' | 'brand' | 'neutral'> = {
  active: 'brand', pending: 'warning', overdue: 'danger', closed: 'success', approved: 'success', rejected: 'neutral',
}

export function LoanHome() {
  const active = loans.filter((l) => l.status === 'active' || l.status === 'overdue')

  return (
    <div className="pb-6">
      <PageHeader title="Loan Management" subtitle={shgInfo.name} />

      <div className="px-4 mt-2 grid grid-cols-2 gap-3">
        <StatCard label="My Outstanding" value="₹22,000" tone="gold" trend="Next EMI 10 Jul" icon={<Landmark className="h-4 w-4" />} />
        <StatCard label="Group Outstanding" value={`₹${(shgInfo.totalLoans / 100000).toFixed(1)}L`} tone="ink" trend={`${active.length} active loans`} icon={<Landmark className="h-4 w-4" />} />
      </div>

      <div className="px-4 mt-5 grid grid-cols-3 gap-2">
        <IconTile to={paths.loanApply} icon={<PlusCircle className="h-5.5 w-5.5" />} label="Apply" tone="brand" />
        <IconTile to={paths.loanApproval} icon={<ClipboardCheck className="h-5.5 w-5.5" />} label="Approvals" tone="gold" />
        <IconTile to={paths.loanTracking} icon={<Radar className="h-5.5 w-5.5" />} label="Tracking" tone="sky" />
      </div>

      <div className="px-4 mt-6">
        <SectionHeader title="Active Loans" action="Track all" actionTo={paths.loanTracking} />
        <div className="space-y-3">
          {active.map((l) => (
            <Link key={l.id} to={paths.loanDetail(l.id)}>
              <Card interactive>
                <div className="flex items-start justify-between">
                  <div className="min-w-0">
                    <p className="text-sm font-bold text-ink-900 truncate">{l.memberName}</p>
                    <p className="text-xs text-ink-500 mt-0.5 truncate">{l.purpose}</p>
                  </div>
                  <Badge tone={statusTone[l.status]}>{l.status}</Badge>
                </div>
                <div className="flex items-end justify-between mt-3">
                  <p className="text-base font-bold font-display text-ink-900">₹{l.outstanding.toLocaleString('en-IN')}</p>
                  <p className="text-xs text-ink-500">of ₹{l.amount.toLocaleString('en-IN')}</p>
                </div>
                <ProgressBar value={l.amount - l.outstanding} max={l.amount} tone={l.status === 'overdue' ? 'danger' : 'gold'} className="mt-2" />
              </Card>
            </Link>
          ))}
        </div>
      </div>
    </div>
  )
}
