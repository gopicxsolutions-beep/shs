import { Link } from 'react-router-dom'
import { CalendarPlus, QrCode, ClipboardList, MapPin, Clock } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Badge } from '../../components/ui/Badge'
import { IconTile } from '../../components/ui/IconTile'
import { SectionHeader } from '../../components/ui/SectionHeader'
import { paths } from '../../routes/paths'
import { meetings } from '../../data/meetings'

export function MeetingsHome() {
  const upcoming = meetings.filter((m) => m.status === 'upcoming')
  const past = meetings.filter((m) => m.status === 'completed')

  return (
    <div className="pb-6">
      <PageHeader title="Meeting Management" />

      <div className="px-4 mt-2 grid grid-cols-3 gap-2">
        <IconTile to={paths.meetingSchedule} icon={<CalendarPlus className="h-5.5 w-5.5" />} label="Schedule" tone="brand" />
        <IconTile to={paths.meetingQr} icon={<QrCode className="h-5.5 w-5.5" />} label="QR Check-in" tone="gold" />
        <IconTile to={paths.meetingAttendance} icon={<ClipboardList className="h-5.5 w-5.5" />} label="Attendance" tone="sky" />
      </div>

      <div className="px-4 mt-6">
        <SectionHeader title="Upcoming" />
        <div className="space-y-3">
          {upcoming.map((m) => (
            <Link key={m.id} to={paths.meetingDetail(m.id)}>
              <Card interactive className="flex items-center gap-3 border-brand-100 bg-brand-50/40">
                <div className="flex h-12 w-12 shrink-0 flex-col items-center justify-center rounded-xl bg-brand-600 text-white">
                  <span className="text-[10px] font-bold uppercase leading-none">{m.date.split(' ')[1]}</span>
                  <span className="text-base font-bold leading-none">{m.date.split(' ')[0]}</span>
                </div>
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-semibold text-ink-900 truncate">{m.agenda}</p>
                  <p className="flex items-center gap-1 text-xs text-ink-500 mt-0.5">
                    <Clock className="h-3 w-3" /> {m.time} <MapPin className="h-3 w-3 ml-1" /> {m.venue}
                  </p>
                </div>
              </Card>
            </Link>
          ))}
        </div>
      </div>

      <div className="px-4 mt-5">
        <SectionHeader title="Past Meetings" />
        <Card className="!p-0 divide-y divide-ink-100">
          {past.map((m) => (
            <Link key={m.id} to={paths.meetingDetail(m.id)} className="flex items-center justify-between px-4 py-3">
              <div className="min-w-0">
                <p className="text-xs font-semibold text-ink-800 truncate">{m.agenda}</p>
                <p className="text-[11px] text-ink-400">{m.date}</p>
              </div>
              <Badge tone={m.attendance / m.total >= 0.9 ? 'success' : 'warning'}>
                {m.attendance}/{m.total} present
              </Badge>
            </Link>
          ))}
        </Card>
      </div>
    </div>
  )
}
