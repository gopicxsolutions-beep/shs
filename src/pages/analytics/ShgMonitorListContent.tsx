import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { Search, Building2 } from 'lucide-react'
import { Card } from '../../components/ui/Card'
import { Badge } from '../../components/ui/Badge'
import { ProgressBar } from '../../components/ui/ProgressBar'
import { Input } from '../../components/ui/Field'
import { paths } from '../../routes/paths'
import { shgsForMonitoring } from '../../data/analytics'

const gradeTone: Record<string, 'success' | 'brand' | 'warning' | 'danger'> = {
  'A+': 'success', A: 'brand', 'B+': 'brand', B: 'warning', C: 'danger',
}

export function ShgMonitorListContent() {
  const [query, setQuery] = useState('')

  const grouped = useMemo(() => {
    const filtered = shgsForMonitoring.filter(
      (g) => g.name.toLowerCase().includes(query.toLowerCase()) || g.village.toLowerCase().includes(query.toLowerCase()),
    )
    const byVillage = new Map<string, typeof filtered>()
    for (const g of filtered) {
      if (!byVillage.has(g.village)) byVillage.set(g.village, [])
      byVillage.get(g.village)!.push(g)
    }
    return byVillage
  }, [query])

  return (
    <>
      <div className="px-4 pt-2">
        <Input
          placeholder="Search by SHG or village"
          icon={<Search className="h-4 w-4" />}
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
      </div>

      {[...grouped.entries()].map(([village, groups]) => (
        <div key={village} className="px-4 mt-6">
          <div className="flex items-center gap-1.5 mb-3">
            <Building2 className="h-4 w-4 text-ink-400" />
            <h2 className="text-[13px] font-bold uppercase tracking-wide text-ink-400">{village}</h2>
            <span className="text-[11px] text-ink-400">· {groups.length} SHGs</span>
          </div>
          <div className="space-y-3">
            {groups.map((g) => (
              <Link key={g.id} to={paths.analyticsShgDetail(g.id)}>
                <Card interactive>
                  <div className="flex items-center justify-between">
                    <div className="min-w-0">
                      <p className="text-sm font-bold text-ink-900 truncate">{g.name}</p>
                      <p className="text-xs text-ink-500 mt-0.5">{g.members} members · ₹{(g.savings / 100000).toFixed(1)}L savings</p>
                    </div>
                    <Badge tone={gradeTone[g.grade] ?? 'neutral'}>{g.grade}</Badge>
                  </div>
                  <div className="flex items-center gap-2 mt-3">
                    <ProgressBar value={g.health} tone={g.health > 80 ? 'brand' : g.health > 60 ? 'gold' : 'danger'} className="flex-1" />
                    <span className="text-xs font-semibold text-ink-600">{g.health}%</span>
                  </div>
                </Card>
              </Link>
            ))}
          </div>
        </div>
      ))}
    </>
  )
}
