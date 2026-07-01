import { useState } from 'react'
import { Link } from 'react-router-dom'
import { Sparkles, User } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
import { Input } from '../../components/ui/Field'
import { Badge } from '../../components/ui/Badge'
import { paths } from '../../routes/paths'
import { useData } from '../../context/DataContext'

const occupations = ['Agriculture', 'Dairy / Livestock', 'Handicrafts', 'Petty Trade', 'Tailoring', 'Other']

export function EligibilityChecker() {
  const { schemes } = useData()
  const [age, setAge] = useState('32')
  const [occupation, setOccupation] = useState(occupations[0])
  const [income, setIncome] = useState('60000')
  const [location, setLocation] = useState('')
  const [checked, setChecked] = useState(false)

  const ageNum = Number(age) || 0
  const incomeNum = Number(income) || 0

  const results = schemes
    .map((s) => {
      let score = 55
      if (ageNum >= 18) score += 15
      if (incomeNum <= 120000) score += 15
      if (s.status === 'approved' || s.status === 'applied' || s.status === 'under_review') score += 5
      if (occupation === 'Other') score -= 5
      score = Math.max(40, Math.min(97, score + (s.id.charCodeAt(2) % 7)))
      return { scheme: s, score }
    })
    .sort((a, b) => b.score - a.score)
    .slice(0, 3)

  return (
    <div className="pb-6">
      <PageHeader title="Eligibility Checker" subtitle="Find schemes that match your profile" />

      <form
        className="px-4 mt-2 space-y-4"
        onSubmit={(e) => {
          e.preventDefault()
          setChecked(true)
        }}
      >
        <div className="grid grid-cols-2 gap-3">
          <Input label="Age" type="number" value={age} onChange={(e) => setAge(e.target.value)} icon={<User className="h-4 w-4" />} required />
          <Input label="Monthly income (₹)" type="number" value={income} onChange={(e) => setIncome(e.target.value)} required />
        </div>

        <label className="block">
          <span className="mb-1.5 block text-xs font-semibold text-ink-600">Occupation</span>
          <div className="rounded-xl border border-ink-200 bg-white px-3.5 focus-within:border-brand-500 focus-within:ring-2 focus-within:ring-brand-100 transition">
            <select
              className="h-11 w-full bg-transparent text-sm text-ink-900 outline-none"
              value={occupation}
              onChange={(e) => setOccupation(e.target.value)}
            >
              {occupations.map((o) => (
                <option key={o} value={o}>{o}</option>
              ))}
            </select>
          </div>
        </label>

        <Input label="Location / Village" placeholder="e.g. Mahbubnagar" value={location} onChange={(e) => setLocation(e.target.value)} />

        <Button type="submit" fullWidth size="lg" className="mt-2" icon={<Sparkles className="h-4 w-4" />}>
          Check Eligibility
        </Button>
      </form>

      {checked && (
        <div className="px-4 mt-6">
          <h2 className="text-[15px] font-bold text-ink-900 font-display mb-3">Matching Schemes</h2>
          <div className="space-y-3">
            {results.map(({ scheme, score }) => (
              <Link key={scheme.id} to={paths.schemeDetail(scheme.id)}>
                <Card interactive>
                  <div className="flex items-start justify-between gap-2">
                    <div className="min-w-0">
                      <Badge tone="brand">{scheme.name}</Badge>
                      <p className="text-sm font-semibold text-ink-900 mt-1.5 truncate">{scheme.fullName}</p>
                    </div>
                    <Badge tone={score >= 80 ? 'success' : score >= 65 ? 'warning' : 'neutral'} className="shrink-0">
                      {score}% match
                    </Badge>
                  </div>
                  <p className="text-xs text-ink-500 mt-2 line-clamp-2">{scheme.benefit}</p>
                </Card>
              </Link>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
