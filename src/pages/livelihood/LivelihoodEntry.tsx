import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { CheckCircle2, IndianRupee } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
import { Input, Textarea } from '../../components/ui/Field'
import { paths } from '../../routes/paths'
import { categoryMeta, type Activity } from '../../data/livelihood'

const categories = Object.keys(categoryMeta) as Activity['category'][]

export function LivelihoodEntry() {
  const navigate = useNavigate()
  const [category, setCategory] = useState<Activity['category']>(categories[0])
  const [production, setProduction] = useState('')
  const [income, setIncome] = useState('5000')
  const [expense, setExpense] = useState('2000')
  const [submitted, setSubmitted] = useState(false)

  if (submitted) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center px-8 text-center">
        <div className="flex h-16 w-16 items-center justify-center rounded-full bg-brand-50 text-brand-600">
          <CheckCircle2 className="h-9 w-9" />
        </div>
        <h1 className="mt-5 font-display text-xl font-bold text-ink-900">Entry recorded!</h1>
        <p className="mt-1.5 text-sm text-ink-500">
          ₹{income} income logged for {category} activity
        </p>
        <Button className="mt-8" fullWidth size="lg" onClick={() => navigate(paths.livelihood)}>
          Back to Livelihood
        </Button>
      </div>
    )
  }

  return (
    <div className="pb-6">
      <PageHeader title="New Livelihood Entry" />
      <form
        className="px-4 mt-2 space-y-4"
        onSubmit={(e) => {
          e.preventDefault()
          setSubmitted(true)
        }}
      >
        <Card>
          <label className="mb-1.5 block text-xs font-semibold text-ink-600">Category</label>
          <select
            value={category}
            onChange={(e) => setCategory(e.target.value as Activity['category'])}
            className="h-11 w-full rounded-xl border border-ink-200 bg-white px-3.5 text-sm text-ink-900 outline-none focus:border-brand-500"
          >
            {categories.map((c) => (
              <option key={c} value={c}>{categoryMeta[c].icon} {c}</option>
            ))}
          </select>
        </Card>

        <Textarea
          label="Production details"
          placeholder="e.g. 180 L milk, 42 garments"
          rows={2}
          value={production}
          onChange={(e) => setProduction(e.target.value)}
          required
        />

        <div className="grid grid-cols-2 gap-3">
          <Input
            label="Income"
            type="number"
            value={income}
            onChange={(e) => setIncome(e.target.value)}
            icon={<IndianRupee className="h-4 w-4" />}
            required
          />
          <Input
            label="Expense"
            type="number"
            value={expense}
            onChange={(e) => setExpense(e.target.value)}
            icon={<IndianRupee className="h-4 w-4" />}
            required
          />
        </div>

        <Input label="Month" type="month" defaultValue="2026-06" required />

        <Button type="submit" fullWidth size="lg" className="mt-2">
          Save Entry
        </Button>
      </form>
    </div>
  )
}
