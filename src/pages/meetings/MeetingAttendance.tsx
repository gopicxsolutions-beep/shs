import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Check, X, CheckCircle2 } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
import { Avatar } from '../../components/ui/Avatar'
import { EmptyState } from '../../components/ui/EmptyState'
import { paths } from '../../routes/paths'
import { members } from '../../data/members'
import { useData } from '../../context/DataContext'

export function MeetingAttendance() {
  const navigate = useNavigate()
  const { meetings, markAttendance } = useData()
  const targetMeeting = meetings.find((m) => m.status === 'upcoming')
  const [present, setPresent] = useState<Record<string, boolean>>(
    Object.fromEntries(members.map((m) => [m.id, true])),
  )
  const [saved, setSaved] = useState(false)
  const count = Object.values(present).filter(Boolean).length

  if (!targetMeeting) {
    return (
      <div>
        <PageHeader title="Digital Attendance" />
        <div className="px-4 pt-8">
          <EmptyState title="No upcoming meeting" description="Schedule a meeting first to take attendance." />
        </div>
      </div>
    )
  }

  if (saved) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center px-8 text-center">
        <div className="flex h-16 w-16 items-center justify-center rounded-full bg-brand-50 text-brand-600">
          <CheckCircle2 className="h-9 w-9" />
        </div>
        <h1 className="mt-5 font-display text-xl font-bold text-ink-900">Attendance saved!</h1>
        <p className="mt-1.5 text-sm text-ink-500">{count} of {members.length} members marked present.</p>
        <Button className="mt-8" fullWidth size="lg" onClick={() => navigate(paths.meetings)}>
          Back to Meetings
        </Button>
      </div>
    )
  }

  return (
    <div className="pb-6">
      <PageHeader title="Digital Attendance" subtitle={`${targetMeeting.agenda} · ${count} of ${members.length} present`} />
      <div className="px-4 mt-2">
        <Card className="!p-0 divide-y divide-ink-100">
          {members.map((m) => (
            <div key={m.id} className="flex items-center gap-3 px-4 py-3">
              <Avatar name={m.name} size="sm" />
              <div className="min-w-0 flex-1">
                <p className="text-xs font-semibold text-ink-800 truncate">{m.name}</p>
                <p className="text-[11px] text-ink-400">{m.role}</p>
              </div>
              <div className="flex gap-1.5">
                <button
                  onClick={() => setPresent((p) => ({ ...p, [m.id]: true }))}
                  className={`flex h-8 w-8 items-center justify-center rounded-full transition ${present[m.id] ? 'bg-brand-600 text-white' : 'bg-ink-100 text-ink-400'}`}
                >
                  <Check className="h-4 w-4" />
                </button>
                <button
                  onClick={() => setPresent((p) => ({ ...p, [m.id]: false }))}
                  className={`flex h-8 w-8 items-center justify-center rounded-full transition ${!present[m.id] ? 'bg-red-500 text-white' : 'bg-ink-100 text-ink-400'}`}
                >
                  <X className="h-4 w-4" />
                </button>
              </div>
            </div>
          ))}
        </Card>
      </div>
      <div className="px-4 mt-5">
        <Button
          fullWidth
          size="lg"
          onClick={() => {
            markAttendance(targetMeeting.id, count)
            setSaved(true)
          }}
        >
          Save Attendance
        </Button>
      </div>
    </div>
  )
}
