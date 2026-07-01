import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { CheckCircle2 } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Button } from '../../components/ui/Button'
import { Input, Textarea } from '../../components/ui/Field'
import { paths } from '../../routes/paths'

export function MeetingSchedule() {
  const navigate = useNavigate()
  const [submitted, setSubmitted] = useState(false)

  if (submitted) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center px-8 text-center">
        <div className="flex h-16 w-16 items-center justify-center rounded-full bg-brand-50 text-brand-600">
          <CheckCircle2 className="h-9 w-9" />
        </div>
        <h1 className="mt-5 font-display text-xl font-bold text-ink-900">Meeting scheduled!</h1>
        <p className="mt-1.5 text-sm text-ink-500">All members will be notified with a reminder.</p>
        <Button className="mt-8" fullWidth size="lg" onClick={() => navigate(paths.meetings)}>
          Back to Meetings
        </Button>
      </div>
    )
  }

  return (
    <div className="pb-6">
      <PageHeader title="Schedule Meeting" />
      <form
        className="px-4 mt-2 space-y-4"
        onSubmit={(e) => {
          e.preventDefault()
          setSubmitted(true)
        }}
      >
        <div className="grid grid-cols-2 gap-3">
          <Input label="Date" type="date" defaultValue="2026-07-12" required />
          <Input label="Time" type="time" defaultValue="16:00" required />
        </div>
        <Input label="Venue" placeholder="Anganwadi Centre, Kondapur" defaultValue="Anganwadi Centre, Kondapur" required />
        <Textarea label="Agenda" placeholder="e.g. Monthly savings review & loan applications" rows={3} required />
        <Button type="submit" fullWidth size="lg" className="mt-2">
          Schedule &amp; Notify Members
        </Button>
      </form>
    </div>
  )
}
