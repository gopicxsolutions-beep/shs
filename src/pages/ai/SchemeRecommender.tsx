import { Link } from 'react-router-dom'
import { Sparkles, ChevronRight } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Badge } from '../../components/ui/Badge'
import { paths } from '../../routes/paths'
import { useData } from '../../context/DataContext'

const recommendations = [
  {
    schemeId: 'sc1',
    match: 94,
    factors: ['Age: 34', 'Occupation: Dairy farming', 'Income: BPL household', 'Location: Rural Telangana'],
  },
  {
    schemeId: 'sc3',
    match: 87,
    factors: ['Occupation: Small business', 'Existing SHG loan repayment: Good', 'Non-farm activity'],
  },
  {
    schemeId: 'sc2',
    match: 76,
    factors: ['Age: 34 (18+)', 'No prior subsidy availed', 'Interested in micro-enterprise'],
  },
]

export function SchemeRecommender() {
  const { schemes } = useData()
  return (
    <div className="pb-6">
      <PageHeader title="Scheme Recommender" subtitle="Schemes matched to your profile by AI" />

      <div className="px-4 mt-2">
        <Card className="flex items-center gap-2 bg-violet-50 border-violet-100">
          <Sparkles className="h-4 w-4 text-violet-600 shrink-0" />
          <p className="text-[11px] text-violet-700 leading-relaxed">
            Recommendations are generated based on your age, occupation, income level and location.
          </p>
        </Card>
      </div>

      <div className="px-4 mt-5 space-y-3">
        {recommendations.map((r) => {
          const scheme = schemes.find((s) => s.id === r.schemeId)
          if (!scheme) return null
          return (
            <Card key={r.schemeId}>
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0">
                  <p className="text-sm font-bold text-ink-900">{scheme.name}</p>
                  <p className="text-xs text-ink-500 mt-0.5 line-clamp-2">{scheme.fullName}</p>
                </div>
                <Badge tone="success" className="shrink-0">{r.match}% match</Badge>
              </div>

              <p className="text-xs text-ink-600 mt-3 leading-relaxed">{scheme.benefit}</p>

              <p className="text-[11px] font-bold uppercase tracking-wide text-ink-400 mt-3 mb-1.5">Why recommended</p>
              <div className="flex flex-wrap gap-1.5">
                {r.factors.map((f) => (
                  <span key={f} className="rounded-full bg-ink-100 px-2.5 py-1 text-[11px] font-medium text-ink-600">
                    {f}
                  </span>
                ))}
              </div>

              <Link
                to={paths.schemeDetail(scheme.id)}
                className="mt-3 flex items-center justify-end gap-0.5 text-xs font-semibold text-brand-600"
              >
                View scheme details
                <ChevronRight className="h-3.5 w-3.5" />
              </Link>
            </Card>
          )
        })}
      </div>
    </div>
  )
}
