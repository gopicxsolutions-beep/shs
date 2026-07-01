import { Link } from 'react-router-dom'
import { Users, Building2, Landmark, ChevronRight } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { paths } from '../../routes/paths'

const sections = [
  {
    to: paths.reportsMember,
    icon: Users,
    tone: 'bg-brand-50 text-brand-600',
    title: 'Member Reports',
    description: 'Savings statement, loan statement & attendance per member',
  },
  {
    to: paths.reportsShg,
    icon: Building2,
    tone: 'bg-gold-50 text-gold-600',
    title: 'SHG Reports',
    description: 'Financial summary, audit report & performance',
  },
  {
    to: paths.reportsFederation,
    icon: Landmark,
    tone: 'bg-violet-50 text-violet-600',
    title: 'Federation Reports',
    description: 'Village-wise SHGs, recovery % & savings growth',
  },
]

export function ReportsHome() {
  return (
    <div className="pb-6">
      <PageHeader title="Reports" subtitle="Generate & view SHG reports" />

      <div className="px-4 mt-2 space-y-3">
        {sections.map((s) => {
          const Icon = s.icon
          return (
            <Link key={s.title} to={s.to}>
              <Card interactive className="flex items-center gap-3">
                <div className={`flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl ${s.tone}`}>
                  <Icon className="h-6 w-6" />
                </div>
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-bold text-ink-900">{s.title}</p>
                  <p className="text-xs text-ink-500 mt-0.5">{s.description}</p>
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
