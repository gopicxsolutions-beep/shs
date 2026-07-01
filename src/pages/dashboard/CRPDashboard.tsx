import { Link } from 'react-router-dom'
import { Building2, GraduationCap, TrendingUp, Radar } from 'lucide-react'
import { StatCard } from '../../components/ui/StatCard'
import { Card } from '../../components/ui/Card'
import { SectionHeader } from '../../components/ui/SectionHeader'
import { Badge } from '../../components/ui/Badge'
import { ProgressBar } from '../../components/ui/ProgressBar'
import { paths } from '../../routes/paths'
import { shgsForMonitoring } from '../../data/analytics'
import { courses } from '../../data/training'

const gradeTone: Record<string, 'success' | 'brand' | 'warning' | 'danger'> = {
  'A+': 'success', A: 'brand', 'B+': 'brand', B: 'warning', C: 'danger',
}

export function CRPDashboard() {
  const avgHealth = Math.round(shgsForMonitoring.reduce((s, g) => s + g.health, 0) / shgsForMonitoring.length)

  return (
    <div className="pb-6">
      <div className="-mt-10 px-4">
        <div className="grid grid-cols-2 gap-3">
          <StatCard label="SHGs Monitored" value={String(shgsForMonitoring.length)} tone="brand" trend="Kondapur cluster" icon={<Building2 className="h-4 w-4" />} />
          <StatCard label="Avg. Health Score" value={`${avgHealth}%`} tone="gold" trend="+4% this quarter" icon={<TrendingUp className="h-4 w-4" />} />
        </div>
      </div>

      <div className="px-4 mt-6">
        <SectionHeader title="SHGs Under Monitoring" action="View all" actionTo={paths.reportsShg} icon={<Radar className="h-4 w-4 text-ink-400" />} />
        <div className="space-y-3">
          {shgsForMonitoring.map((g) => (
            <Card key={g.id}>
              <div className="flex items-center justify-between">
                <div className="min-w-0">
                  <p className="text-sm font-bold text-ink-900 truncate">{g.name}</p>
                  <p className="text-xs text-ink-500 mt-0.5">{g.village} · {g.members} members</p>
                </div>
                <Badge tone={gradeTone[g.grade] ?? 'neutral'}>{g.grade}</Badge>
              </div>
              <div className="flex items-center gap-2 mt-3">
                <ProgressBar value={g.health} tone={g.health > 80 ? 'brand' : g.health > 60 ? 'gold' : 'danger'} className="flex-1" />
                <span className="text-xs font-semibold text-ink-600">{g.health}%</span>
              </div>
            </Card>
          ))}
        </div>
      </div>

      <div className="px-4 mt-5">
        <SectionHeader title="Training Updates" action="Manage" actionTo={paths.training} icon={<GraduationCap className="h-4 w-4 text-ink-400" />} />
        <Card className="!p-0 divide-y divide-ink-100">
          {courses.slice(0, 3).map((c) => (
            <Link key={c.id} to={paths.trainingDetail(c.id)} className="flex items-center justify-between px-4 py-3">
              <div className="min-w-0">
                <p className="text-xs font-semibold text-ink-800 truncate">{c.title}</p>
                <p className="text-[11px] text-ink-400">{c.topic}</p>
              </div>
              <Badge tone={c.progress === 100 ? 'success' : 'neutral'}>{c.progress}%</Badge>
            </Link>
          ))}
        </Card>
      </div>
    </div>
  )
}
