import { CheckCircle2, ListTodo } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Badge } from '../../components/ui/Badge'
import { minutesOfMeeting } from '../../data/meetings'

export function MeetingMom() {
  return (
    <div className="pb-6">
      <PageHeader title="Minutes of Meeting" />

      <div className="px-4 mt-2">
        <h2 className="text-[15px] font-bold text-ink-900 font-display mb-3">Decisions Taken</h2>
        <Card className="!p-0 divide-y divide-ink-100">
          {minutesOfMeeting.decisions.map((d, i) => (
            <div key={i} className="flex items-start gap-2.5 px-4 py-3">
              <CheckCircle2 className="h-4 w-4 mt-0.5 shrink-0 text-brand-600" />
              <p className="text-xs text-ink-700 leading-relaxed">{d}</p>
            </div>
          ))}
        </Card>
      </div>

      <div className="px-4 mt-5">
        <h2 className="text-[15px] font-bold text-ink-900 font-display mb-3">Action Items</h2>
        <div className="space-y-3">
          {minutesOfMeeting.actionItems.map((a, i) => (
            <Card key={i} className="flex items-center gap-3">
              <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-gold-50 text-gold-600">
                <ListTodo className="h-4 w-4" />
              </div>
              <div className="min-w-0 flex-1">
                <p className="text-xs font-semibold text-ink-800">{a.task}</p>
                <p className="text-[11px] text-ink-400 mt-0.5">Owner: {a.owner}</p>
              </div>
              <Badge tone="neutral">{a.due}</Badge>
            </Card>
          ))}
        </div>
      </div>
    </div>
  )
}
