import { ServerCog, Gauge, Users, HardDrive } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { StatCard } from '../../components/ui/StatCard'
import { Badge } from '../../components/ui/Badge'
import { ProgressBar } from '../../components/ui/ProgressBar'
import { SectionHeader } from '../../components/ui/SectionHeader'

const logs = [
  { time: '10:42 AM', message: 'Database backup completed successfully', level: 'info' as const },
  { time: '09:58 AM', message: 'API latency spike detected on /savings endpoint', level: 'warning' as const },
  { time: '08:30 AM', message: 'Scheduled maintenance window completed', level: 'info' as const },
  { time: 'Yesterday', message: 'Failed login attempts threshold exceeded for 1 account', level: 'danger' as const },
  { time: 'Yesterday', message: 'New SHG "Gayatri SHG" registered', level: 'info' as const },
  { time: '2 days ago', message: 'Storage usage crossed 70% on primary node', level: 'warning' as const },
]

const levelTone = { info: 'info', warning: 'warning', danger: 'danger' } as const

export function SystemMonitoring() {
  return (
    <div className="pb-6">
      <PageHeader title="System Monitoring" subtitle="Platform health & activity" />

      <div className="px-4 mt-2 grid grid-cols-2 gap-3">
        <StatCard label="Uptime" value="99.98%" tone="brand" trend="Last 30 days" icon={<ServerCog className="h-4 w-4" />} />
        <StatCard label="API Latency" value="182ms" tone="ink" trend="p95 response time" icon={<Gauge className="h-4 w-4" />} />
        <StatCard label="Active Sessions" value="1,284" tone="gold" trend="Right now" icon={<Users className="h-4 w-4" />} />
        <StatCard label="Storage Used" value="68%" tone="danger" trend="512 GB of 750 GB" icon={<HardDrive className="h-4 w-4" />} />
      </div>

      <div className="px-4 mt-6">
        <SectionHeader title="Storage" icon={<HardDrive className="h-4 w-4 text-ink-400" />} />
        <Card>
          <div className="flex items-center justify-between mb-1.5">
            <p className="text-xs text-ink-500">512 GB used of 750 GB</p>
            <p className="text-xs font-semibold text-ink-700">68%</p>
          </div>
          <ProgressBar value={68} tone="gold" />
        </Card>
      </div>

      <div className="px-4 mt-5">
        <SectionHeader title="Recent System Logs" icon={<ServerCog className="h-4 w-4 text-ink-400" />} />
        <Card className="!p-0 divide-y divide-ink-100">
          {logs.map((l) => (
            <div key={l.message} className="flex items-start justify-between gap-3 px-4 py-3">
              <div className="min-w-0">
                <p className="text-xs font-semibold text-ink-800 leading-snug">{l.message}</p>
                <p className="text-[11px] text-ink-400 mt-0.5">{l.time}</p>
              </div>
              <Badge tone={levelTone[l.level]} className="shrink-0">{l.level}</Badge>
            </div>
          ))}
        </Card>
      </div>
    </div>
  )
}
