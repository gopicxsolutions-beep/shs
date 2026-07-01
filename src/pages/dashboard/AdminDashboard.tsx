import { Link } from 'react-router-dom'
import { UsersRound, FileCog, ServerCog, FileBarChart2, ShieldAlert } from 'lucide-react'
import { StatCard } from '../../components/ui/StatCard'
import { Card } from '../../components/ui/Card'
import { SectionHeader } from '../../components/ui/SectionHeader'
import { IconTile } from '../../components/ui/IconTile'
import { Badge } from '../../components/ui/Badge'
import { paths } from '../../routes/paths'
import { kpis } from '../../data/analytics'

export function AdminDashboard() {
  return (
    <div className="pb-6">
      <div className="-mt-10 px-4">
        <div className="grid grid-cols-2 gap-3">
          <StatCard label="Total SHGs" value={String(kpis.totalSHGs)} tone="brand" trend={`${kpis.activeMembers.toLocaleString('en-IN')} members`} icon={<UsersRound className="h-4 w-4" />} />
          <StatCard label="System Uptime" value="99.98%" tone="ink" trend="All services normal" icon={<ServerCog className="h-4 w-4" />} />
        </div>
      </div>

      <div className="px-4 mt-5 grid grid-cols-4 gap-2">
        <IconTile to={paths.adminUsers} icon={<UsersRound className="h-5.5 w-5.5" />} label="Users" tone="brand" />
        <IconTile to={paths.adminSchemes} icon={<FileCog className="h-5.5 w-5.5" />} label="Schemes" tone="gold" />
        <IconTile to={paths.adminMonitoring} icon={<ServerCog className="h-5.5 w-5.5" />} label="Monitoring" tone="sky" />
        <IconTile to={paths.reportsFederation} icon={<FileBarChart2 className="h-5.5 w-5.5" />} label="Reports" tone="violet" />
      </div>

      <div className="px-4 mt-5">
        <Card className="flex items-center gap-3 bg-amber-50 border-amber-100">
          <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-amber-100 text-amber-600">
            <ShieldAlert className="h-5 w-5" />
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-sm font-bold text-amber-800">3 accounts pending verification</p>
            <p className="text-xs text-amber-600">Aadhaar e-KYC review required</p>
          </div>
          <Link to={paths.adminUsers} className="text-xs font-semibold text-amber-700 shrink-0">Review</Link>
        </Card>
      </div>

      <div className="px-4 mt-5">
        <SectionHeader title="Platform Snapshot" action="Analytics" actionTo={paths.analytics} />
        <div className="grid grid-cols-2 gap-3">
          <Card className="!p-3.5">
            <p className="text-xs text-ink-500">Loans Disbursed</p>
            <p className="text-lg font-bold font-display text-ink-900 mt-1">₹{(kpis.loansDisbursed / 10000000).toFixed(2)}Cr</p>
          </Card>
          <Card className="!p-3.5">
            <p className="text-xs text-ink-500">Training Completion</p>
            <p className="text-lg font-bold font-display text-brand-700 mt-1">{kpis.trainingCompletion}%</p>
          </Card>
        </div>
      </div>

      <div className="px-4 mt-5">
        <SectionHeader title="Recent System Activity" />
        <Card className="!p-0 divide-y divide-ink-100">
          {[
            { text: 'New SHG "Gayatri SHG" registered', time: '2h ago', tone: 'success' as const },
            { text: 'PMEGP scheme details updated', time: '5h ago', tone: 'info' as const },
            { text: 'Scheduled backup completed', time: '1d ago', tone: 'neutral' as const },
          ].map((a) => (
            <div key={a.text} className="flex items-center justify-between px-4 py-3">
              <p className="text-xs text-ink-700">{a.text}</p>
              <Badge tone={a.tone}>{a.time}</Badge>
            </div>
          ))}
        </Card>
      </div>
    </div>
  )
}
