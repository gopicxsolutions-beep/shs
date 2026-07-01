import { Award } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Badge } from '../../components/ui/Badge'
import { EmptyState } from '../../components/ui/EmptyState'
import { certificates } from '../../data/training'

export function Certificates() {
  return (
    <div className="pb-6">
      <PageHeader title="Certificates" subtitle={`${certificates.length} earned`} />

      <div className="px-4 mt-2 space-y-3">
        {certificates.length === 0 ? (
          <EmptyState
            icon={<Award className="h-6 w-6" />}
            title="No certificates yet"
            description="Complete a course and pass its quiz to earn a certificate."
          />
        ) : (
          certificates.map((c) => (
            <Card key={c.id} className="relative overflow-hidden bg-gradient-to-br from-gold-50 to-white border-gold-100">
              <div className="absolute -right-5 -top-6 h-20 w-20 rounded-full bg-gold-100/60" />
              <div className="relative flex items-start gap-3">
                <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-gold-500 text-white shadow-[0_6px_16px_-4px_rgba(242,144,13,0.5)]">
                  <Award className="h-6 w-6" />
                </div>
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-bold text-ink-900">{c.title}</p>
                  <p className="text-xs text-ink-500 mt-0.5">Issued {c.date}</p>
                  <div className="mt-2">
                    <Badge tone="success">Score {c.score}%</Badge>
                  </div>
                </div>
              </div>
            </Card>
          ))
        )}
      </div>
    </div>
  )
}
