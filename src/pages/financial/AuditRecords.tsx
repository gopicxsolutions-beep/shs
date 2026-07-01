import { ShieldCheck, ShieldAlert } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Badge } from '../../components/ui/Badge'
import { FinanceTabs } from './CashBook'
import { auditRecords } from '../../data/financial'

export function AuditRecords() {
  return (
    <div className="pb-6">
      <PageHeader title="Audit Records" />
      <div className="mt-2"><FinanceTabs /></div>

      <div className="px-4 mt-4 space-y-3">
        {auditRecords.map((a) => (
          <Card key={a.id} className="flex items-start gap-3">
            <div className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-xl ${a.status === 'Clean' ? 'bg-brand-50 text-brand-600' : 'bg-amber-50 text-amber-600'}`}>
              {a.status === 'Clean' ? <ShieldCheck className="h-5 w-5" /> : <ShieldAlert className="h-5 w-5" />}
            </div>
            <div className="min-w-0 flex-1">
              <p className="text-sm font-bold text-ink-900">{a.title}</p>
              <p className="text-xs text-ink-500 mt-0.5">{a.auditor} · {a.date}</p>
            </div>
            <Badge tone={a.status === 'Clean' ? 'success' : 'warning'}>{a.status}</Badge>
          </Card>
        ))}
      </div>
    </div>
  )
}
