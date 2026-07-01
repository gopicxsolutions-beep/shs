import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Wallet, CheckCircle2 } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
import { Input } from '../../components/ui/Field'
import { SegmentedTabs } from '../../components/ui/SegmentedTabs'
import { members } from '../../data/members'
import { useData } from '../../context/DataContext'
import { paths } from '../../routes/paths'

export function SavingsEntry() {
  const navigate = useNavigate()
  const { addSavingsEntry } = useData()
  const [member, setMember] = useState(members[0].name)
  const [amount, setAmount] = useState('500')
  const [frequency, setFrequency] = useState<'Daily' | 'Weekly' | 'Monthly'>('Weekly')
  const [mode, setMode] = useState<'Cash' | 'UPI' | 'Bank Transfer'>('Cash')
  const [date, setDate] = useState('2026-06-28')
  const [submitted, setSubmitted] = useState(false)

  if (submitted) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center px-8 text-center">
        <div className="flex h-16 w-16 items-center justify-center rounded-full bg-brand-50 text-brand-600">
          <CheckCircle2 className="h-9 w-9" />
        </div>
        <h1 className="mt-5 font-display text-xl font-bold text-ink-900">Savings recorded!</h1>
        <p className="mt-1.5 text-sm text-ink-500">₹{amount} added for {member} via {mode}</p>
        <Button className="mt-8" fullWidth size="lg" onClick={() => navigate(paths.savings)}>
          Done
        </Button>
      </div>
    )
  }

  return (
    <div className="pb-6">
      <PageHeader title="New Savings Entry" />
      <form
        className="px-4 mt-2 space-y-4"
        onSubmit={(e) => {
          e.preventDefault()
          addSavingsEntry({
            memberName: member,
            amount: Number(amount),
            mode,
            type: frequency,
            date: new Date(date).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' }),
          })
          setSubmitted(true)
        }}
      >
        <Card>
          <label className="mb-1.5 block text-xs font-semibold text-ink-600">Member</label>
          <select
            value={member}
            onChange={(e) => setMember(e.target.value)}
            className="h-11 w-full rounded-xl border border-ink-200 bg-white px-3.5 text-sm text-ink-900 outline-none focus:border-brand-500"
          >
            {members.map((m) => (
              <option key={m.id} value={m.name}>{m.name}</option>
            ))}
          </select>
        </Card>

        <Input
          label="Amount"
          type="number"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          icon={<Wallet className="h-4 w-4" />}
          suffix={<span className="text-xs text-ink-400">INR</span>}
          required
        />

        <div>
          <label className="mb-1.5 block text-xs font-semibold text-ink-600">Frequency</label>
          <SegmentedTabs
            options={[
              { value: 'Daily', label: 'Daily' },
              { value: 'Weekly', label: 'Weekly' },
              { value: 'Monthly', label: 'Monthly' },
            ]}
            value={frequency}
            onChange={(v) => setFrequency(v as typeof frequency)}
          />
        </div>

        <div>
          <label className="mb-1.5 block text-xs font-semibold text-ink-600">Payment Mode</label>
          <SegmentedTabs
            options={[
              { value: 'Cash', label: 'Cash' },
              { value: 'UPI', label: 'UPI' },
              { value: 'Bank Transfer', label: 'Bank' },
            ]}
            value={mode}
            onChange={(v) => setMode(v as typeof mode)}
          />
        </div>

        <Input label="Date" type="date" value={date} onChange={(e) => setDate(e.target.value)} required />

        <Button type="submit" fullWidth size="lg" className="mt-2">
          Save Entry
        </Button>
      </form>
    </div>
  )
}
