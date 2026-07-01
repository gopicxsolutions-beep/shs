import { Link } from 'react-router-dom'
import { ListChecks, Radar, Landmark } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Badge } from '../../components/ui/Badge'
import { IconTile } from '../../components/ui/IconTile'
import { SectionHeader } from '../../components/ui/SectionHeader'
import { paths } from '../../routes/paths'
import { useData } from '../../context/DataContext'

type Status = 'not_applied' | 'applied' | 'under_review' | 'approved' | 'rejected'

const statusTone: Record<Status, 'success' | 'warning' | 'info' | 'danger' | 'neutral'> = {
  approved: 'success',
  under_review: 'warning',
  applied: 'info',
  rejected: 'danger',
  not_applied: 'neutral',
}

const statusLabel: Record<Status, string> = {
  approved: 'Approved',
  under_review: 'Under Review',
  applied: 'Applied',
  rejected: 'Rejected',
  not_applied: 'Not Applied',
}

export function SchemeRepository() {
  const { schemes } = useData()
  return (
    <div className="pb-6">
      <PageHeader title="Government Schemes" subtitle={`${schemes.length} schemes available`} />

      <div className="px-4 mt-2 grid grid-cols-2 gap-2">
        <IconTile to={paths.schemeEligibility} icon={<ListChecks className="h-5.5 w-5.5" />} label="Eligibility Checker" tone="brand" />
        <IconTile to={paths.schemeTracking} icon={<Radar className="h-5.5 w-5.5" />} label="Application Tracking" tone="gold" />
      </div>

      <div className="px-4 mt-6">
        <SectionHeader title="All Schemes" icon={<Landmark className="h-4 w-4 text-ink-400" />} />
        <div className="space-y-3">
          {schemes.map((s) => {
            const status = (s.status ?? 'not_applied') as Status
            return (
              <Link key={s.id} to={paths.schemeDetail(s.id)}>
                <Card interactive>
                  <div className="flex items-start justify-between gap-2">
                    <div className="min-w-0">
                      <div className="flex items-center gap-2">
                        <Badge tone="brand">{s.name}</Badge>
                      </div>
                      <p className="text-sm font-semibold text-ink-900 mt-1.5 line-clamp-2">{s.fullName}</p>
                    </div>
                    <Badge tone={statusTone[status]} className="shrink-0">{statusLabel[status]}</Badge>
                  </div>
                  <p className="text-xs text-ink-500 mt-2 line-clamp-2">{s.benefit}</p>
                  {s.deadline && (
                    <p className="text-[11px] text-gold-700 mt-2 font-semibold">Deadline: {s.deadline}</p>
                  )}
                </Card>
              </Link>
            )
          })}
        </div>
      </div>
    </div>
  )
}
