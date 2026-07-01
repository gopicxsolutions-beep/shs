import { Link } from 'react-router-dom'
import { Sparkles, TrendingUp, FileCheck2, LineChart, Mic, ChevronRight } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { paths } from '../../routes/paths'

const modules = [
  {
    to: paths.aiFinancialAdvisor,
    icon: TrendingUp,
    title: 'Financial Advisor',
    description: 'Credit score, savings tips & loan eligibility insights',
  },
  {
    to: paths.aiSchemeRecommender,
    icon: FileCheck2,
    title: 'Scheme Recommender',
    description: 'Government schemes matched to your profile',
  },
  {
    to: paths.aiMarketAdvisor,
    icon: LineChart,
    title: 'Market Advisor',
    description: 'Demand forecasts & pricing trends for your products',
  },
  {
    to: paths.supportVoice,
    icon: Mic,
    title: 'Voice Assistant',
    description: 'Ask Saathi in Telugu, Hindi or English',
  },
]

export function AIHub() {
  return (
    <div className="pb-6">
      <PageHeader title="AI-Powered Modules" subtitle="Smart insights built for your SHG" />

      <div className="px-4 mt-2">
        <Card className="flex items-center gap-3 bg-gradient-to-r from-violet-600 to-violet-500 text-white">
          <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl bg-white/15">
            <Sparkles className="h-5.5 w-5.5" />
          </div>
          <div className="min-w-0 flex-1">
            <p className="text-sm font-bold">Saathi Intelligence</p>
            <p className="text-xs text-white/75">AI-generated insights to help you grow and save smarter</p>
          </div>
        </Card>
      </div>

      <div className="px-4 mt-5 space-y-3">
        {modules.map((m) => {
          const Icon = m.icon
          return (
            <Link key={m.title} to={m.to}>
              <Card interactive className="flex items-center gap-3">
                <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-violet-50 text-violet-600">
                  <Icon className="h-6 w-6" />
                </div>
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-bold text-ink-900">{m.title}</p>
                  <p className="text-xs text-ink-500 mt-0.5">{m.description}</p>
                </div>
                <ChevronRight className="h-4 w-4 shrink-0 text-ink-300" />
              </Card>
            </Link>
          )
        })}
      </div>
    </div>
  )
}
