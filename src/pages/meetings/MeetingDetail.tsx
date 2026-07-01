import { Link, useParams } from 'react-router-dom'
import { CalendarDays, MapPin, Users, FileText } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Badge } from '../../components/ui/Badge'
import { EmptyState } from '../../components/ui/EmptyState'
import { paths } from '../../routes/paths'
import { useData } from '../../context/DataContext'

export function MeetingDetail() {
  const { id } = useParams()
  const { meetings } = useData()
  const meeting = meetings.find((m) => m.id === id)

  if (!meeting) {
    return (
      <div>
        <PageHeader title="Meeting" />
        <div className="px-4 pt-8"><EmptyState title="Meeting not found" /></div>
      </div>
    )
  }

  return (
    <div className="pb-6">
      <PageHeader title="Meeting Details" />
      <div className="px-4 mt-2">
        <Card>
          <Badge tone={meeting.status === 'upcoming' ? 'brand' : 'success'}>{meeting.status}</Badge>
          <p className="text-base font-bold font-display text-ink-900 mt-2">{meeting.agenda}</p>
          <div className="mt-3 space-y-2 text-sm text-ink-600">
            <p className="flex items-center gap-2"><CalendarDays className="h-4 w-4 text-ink-400" /> {meeting.date} · {meeting.time}</p>
            <p className="flex items-center gap-2"><MapPin className="h-4 w-4 text-ink-400" /> {meeting.venue}</p>
            <p className="flex items-center gap-2"><Users className="h-4 w-4 text-ink-400" /> {meeting.attendance}/{meeting.total} attended</p>
          </div>
        </Card>
      </div>

      {meeting.status === 'completed' && (
        <div className="px-4 mt-4">
          <Link to={paths.meetingMom(meeting.id)}>
            <Card interactive className="flex items-center gap-3">
              <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-gold-50 text-gold-600">
                <FileText className="h-5 w-5" />
              </div>
              <div className="flex-1">
                <p className="text-sm font-bold text-ink-900">Minutes of Meeting</p>
                <p className="text-xs text-ink-500">Decisions taken & action items</p>
              </div>
            </Card>
          </Link>
        </div>
      )}
    </div>
  )
}
