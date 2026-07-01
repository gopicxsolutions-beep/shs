import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { CheckCircle2, Ticket } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
import { Badge } from '../../components/ui/Badge'
import { Input, Textarea } from '../../components/ui/Field'
import { paths } from '../../routes/paths'

const categories = ['Savings', 'Loan', 'Meeting / Attendance', 'Scheme', 'Account / Profile', 'Other']

const myTickets = [
  { id: 'tk1', subject: 'UPI savings entry not reflecting', category: 'Savings', status: 'open' as const, date: '26 Jun 2026' },
  { id: 'tk2', subject: 'Request to update mobile number', category: 'Account / Profile', status: 'resolved' as const, date: '18 Jun 2026' },
  { id: 'tk3', subject: 'MUDRA scheme application query', category: 'Scheme', status: 'resolved' as const, date: '02 Jun 2026' },
]

const statusTone = { open: 'warning', resolved: 'success' } as const

export function RaiseTicket() {
  const navigate = useNavigate()
  const [subject, setSubject] = useState('')
  const [category, setCategory] = useState(categories[0])
  const [description, setDescription] = useState('')
  const [submitted, setSubmitted] = useState(false)

  if (submitted) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center px-8 text-center">
        <div className="flex h-16 w-16 items-center justify-center rounded-full bg-brand-50 text-brand-600">
          <CheckCircle2 className="h-9 w-9" />
        </div>
        <h1 className="mt-5 font-display text-xl font-bold text-ink-900">Ticket raised!</h1>
        <p className="mt-1.5 text-sm text-ink-500">
          Your support ticket "{subject}" has been submitted. Our team will respond within 24 hours.
        </p>
        <Button className="mt-8" fullWidth size="lg" onClick={() => navigate(paths.support)}>
          Back to Support
        </Button>
      </div>
    )
  }

  return (
    <div className="pb-6">
      <PageHeader title="Raise a Ticket" />
      <form
        className="px-4 mt-2 space-y-4"
        onSubmit={(e) => {
          e.preventDefault()
          setSubmitted(true)
        }}
      >
        <Input
          label="Subject"
          placeholder="e.g. Savings entry not verified"
          value={subject}
          onChange={(e) => setSubject(e.target.value)}
          required
        />

        <label className="block">
          <span className="mb-1.5 block text-xs font-semibold text-ink-600">Category</span>
          <div className="rounded-xl border border-ink-200 bg-white px-3.5 focus-within:border-brand-500 focus-within:ring-2 focus-within:ring-brand-100 transition">
            <select
              value={category}
              onChange={(e) => setCategory(e.target.value)}
              className="h-11 w-full bg-transparent text-sm text-ink-900 outline-none"
            >
              {categories.map((c) => (
                <option key={c} value={c}>{c}</option>
              ))}
            </select>
          </div>
        </label>

        <Textarea
          label="Description"
          placeholder="Describe your issue in detail..."
          rows={4}
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          required
        />

        <Button type="submit" fullWidth size="lg" className="mt-2">
          Submit Ticket
        </Button>
      </form>

      <div className="px-4 mt-7">
        <p className="text-xs font-bold uppercase tracking-wide text-ink-400 mb-2">My Tickets</p>
        <div className="space-y-3">
          {myTickets.map((t) => (
            <Card key={t.id} className="flex items-center gap-3">
              <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-sky-50 text-sky-600">
                <Ticket className="h-4 w-4" />
              </div>
              <div className="min-w-0 flex-1">
                <p className="text-xs font-semibold text-ink-800 truncate">{t.subject}</p>
                <p className="text-[11px] text-ink-400 mt-0.5">{t.category} · {t.date}</p>
              </div>
              <Badge tone={statusTone[t.status]}>{t.status === 'open' ? 'Open' : 'Resolved'}</Badge>
            </Card>
          ))}
        </div>
      </div>
    </div>
  )
}
