import { useParams } from 'react-router-dom'
import { AreaChart, Area, ResponsiveContainer } from 'recharts'
import { Building2, Users, Wallet, TrendingUp, ShieldCheck } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Badge } from '../../components/ui/Badge'
import { ProgressBar } from '../../components/ui/ProgressBar'
import { EmptyState } from '../../components/ui/EmptyState'
import { shgsForMonitoring } from '../../data/analytics'
import { savingsMonthlyTrend } from '../../data/savings'

const gradeTone: Record<string, 'success' | 'brand' | 'warning' | 'danger'> = {
  'A+': 'success', A: 'brand', 'B+': 'brand', B: 'warning', C: 'danger',
}

export function ShgMonitorDetail() {
  const { id } = useParams()
  const shg = shgsForMonitoring.find((g) => g.id === id)

  if (!shg) {
    return (
      <div>
        <PageHeader title="SHG" />
        <div className="px-4 pt-8"><EmptyState title="SHG not found" /></div>
      </div>
    )
  }

  return (
    <div className="pb-6">
      <PageHeader title={shg.name} subtitle={shg.village} />

      <div className="px-4 mt-2">
        <Card className="flex items-center gap-3">
          <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-brand-50 text-brand-600">
            <Building2 className="h-6 w-6" />
          </div>
          <div className="min-w-0 flex-1">
            <p className="text-sm font-bold text-ink-900 truncate">{shg.name}</p>
            <p className="text-xs text-ink-500 mt-0.5">{shg.village} · {shg.members} members</p>
          </div>
          <Badge tone={gradeTone[shg.grade] ?? 'neutral'}>{shg.grade}</Badge>
        </Card>
      </div>

      <div className="px-4 mt-4 grid grid-cols-3 gap-2">
        <Card className="!p-3 text-center">
          <Users className="h-4 w-4 mx-auto text-ink-400" />
          <p className="text-sm font-bold text-ink-900 mt-1.5">{shg.members}</p>
          <p className="text-[10px] text-ink-500">Members</p>
        </Card>
        <Card className="!p-3 text-center">
          <Wallet className="h-4 w-4 mx-auto text-ink-400" />
          <p className="text-sm font-bold text-ink-900 mt-1.5">₹{(shg.savings / 100000).toFixed(1)}L</p>
          <p className="text-[10px] text-ink-500">Savings</p>
        </Card>
        <Card className="!p-3 text-center">
          <ShieldCheck className="h-4 w-4 mx-auto text-ink-400" />
          <p className="text-sm font-bold text-ink-900 mt-1.5">{shg.grade}</p>
          <p className="text-[10px] text-ink-500">Grading</p>
        </Card>
      </div>

      <div className="px-4 mt-5">
        <div className="flex items-center gap-2 mb-2">
          <TrendingUp className="h-4 w-4 text-ink-400" />
          <h2 className="text-[15px] font-bold text-ink-900 font-display">Health Score</h2>
        </div>
        <Card>
          <div className="flex items-center gap-3">
            <ProgressBar
              value={shg.health}
              tone={shg.health > 80 ? 'brand' : shg.health > 60 ? 'gold' : 'danger'}
              className="flex-1"
            />
            <span className="text-sm font-bold text-ink-900">{shg.health}%</span>
          </div>
          <p className="text-[11px] text-ink-500 mt-2">
            Based on savings regularity, attendance, loan recovery, and audit compliance.
          </p>
        </Card>
      </div>

      <div className="px-4 mt-5">
        <h2 className="text-[15px] font-bold text-ink-900 font-display mb-3">Savings Trend</h2>
        <Card>
          <div className="h-32">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={savingsMonthlyTrend}>
                <defs>
                  <linearGradient id="shgMonitorGrad" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="#18ab7c" stopOpacity={0.4} />
                    <stop offset="100%" stopColor="#18ab7c" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <Area type="monotone" dataKey="amount" stroke="#0e8a66" strokeWidth={2} fill="url(#shgMonitorGrad)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </Card>
      </div>
    </div>
  )
}
