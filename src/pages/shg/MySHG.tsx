import { Link } from 'react-router-dom'
import { MapPin, Landmark, FileText, Users, ChevronRight, Building2 } from 'lucide-react'
import { Card } from '../../components/ui/Card'
import { Badge } from '../../components/ui/Badge'
import { Avatar } from '../../components/ui/Avatar'
import { SectionHeader } from '../../components/ui/SectionHeader'
import { paths } from '../../routes/paths'
import { shgInfo, documents } from '../../data/shg'
import { members } from '../../data/members'
import { shgsForMonitoring } from '../../data/analytics'
import { useApp } from '../../context/AppContext'
import { ShgMonitorListContent } from '../analytics/ShgMonitorListContent'

export function MySHG() {
  const { user } = useApp()

  if (user.role === 'crp' || user.role === 'clf' || user.role === 'admin') {
    return (
      <div className="pb-6">
        <div className="px-4 pb-3 pt-[calc(env(safe-area-inset-top)+1.25rem)]">
          <h1 className="font-display text-xl font-bold text-ink-900">
            {user.role === 'clf' ? 'Village Organisations' : 'SHGs Under Monitoring'}
          </h1>
          <p className="text-xs text-ink-500 mt-0.5">{shgsForMonitoring.length} groups under your cluster</p>
        </div>
        <ShgMonitorListContent />
      </div>
    )
  }

  return (
    <div className="pb-6">
      <div className="bg-gradient-to-br from-brand-700 to-brand-500 px-4 pb-8 pt-[calc(env(safe-area-inset-top)+1.25rem)] text-white">
        <div className="flex items-center gap-3">
          <div className="flex h-14 w-14 shrink-0 items-center justify-center rounded-2xl bg-white/15">
            <Building2 className="h-7 w-7" />
          </div>
          <div className="min-w-0 flex-1">
            <div className="flex items-center gap-2">
              <h1 className="font-display text-lg font-bold truncate">{shgInfo.name}</h1>
              <Badge tone="gold">{shgInfo.grade}</Badge>
            </div>
            <p className="flex items-center gap-1 text-xs text-white/75 mt-0.5">
              <MapPin className="h-3 w-3" /> {shgInfo.village}, {shgInfo.mandal}, {shgInfo.district}
            </p>
          </div>
        </div>

        <div className="mt-5 grid grid-cols-3 gap-2 rounded-2xl bg-white/10 p-3 backdrop-blur">
          <div className="text-center">
            <p className="text-sm font-bold">{shgInfo.memberCount}</p>
            <p className="text-[10px] text-white/70">Members</p>
          </div>
          <div className="text-center border-x border-white/15">
            <p className="text-sm font-bold">₹{(shgInfo.totalSavings / 100000).toFixed(1)}L</p>
            <p className="text-[10px] text-white/70">Savings</p>
          </div>
          <div className="text-center">
            <p className="text-sm font-bold">₹{(shgInfo.totalLoans / 100000).toFixed(1)}L</p>
            <p className="text-[10px] text-white/70">Loans</p>
          </div>
        </div>
      </div>

      <div className="px-4 -mt-4">
        <Card>
          <p className="text-xs font-bold uppercase tracking-wide text-ink-400 mb-2">Group Information</p>
          <dl className="space-y-2.5">
            {[
              ['Registration Number', shgInfo.regNumber],
              ['Formation Date', shgInfo.formationDate],
              ['Village Organisation', shgInfo.vo],
              ['Federation (CLF)', shgInfo.clf],
              ['Bank Account', `${shgInfo.bankName} · ${shgInfo.bankAccount}`],
            ].map(([k, v]) => (
              <div key={k} className="flex items-center justify-between gap-4">
                <dt className="text-xs text-ink-500">{k}</dt>
                <dd className="text-xs font-semibold text-ink-800 text-right">{v}</dd>
              </div>
            ))}
          </dl>
        </Card>
      </div>

      <div className="px-4 mt-5">
        <SectionHeader title="Member Directory" action="View all" actionTo={paths.shgMembers} icon={<Users className="h-4 w-4 text-ink-400" />} />
        <Card className="!p-0">
          <div className="flex items-center gap-2 overflow-x-auto no-scrollbar px-4 py-4">
            {members.slice(0, 8).map((m) => (
              <Link key={m.id} to={paths.shgMember(m.id)} className="flex shrink-0 flex-col items-center gap-1 w-14">
                <Avatar name={m.name} size="lg" />
                <span className="text-[10px] font-medium text-ink-600 truncate w-14 text-center">{m.name.split(' ')[0]}</span>
              </Link>
            ))}
            <Link to={paths.shgMembers} className="flex shrink-0 flex-col items-center gap-1 w-14">
              <div className="flex h-14 w-14 items-center justify-center rounded-full bg-ink-100 text-ink-500">
                <ChevronRight className="h-5 w-5" />
              </div>
              <span className="text-[10px] font-medium text-ink-500">See all</span>
            </Link>
          </div>
        </Card>
      </div>

      <div className="px-4 mt-5">
        <SectionHeader title="Documents" action="View all" actionTo={paths.shgDocuments} icon={<FileText className="h-4 w-4 text-ink-400" />} />
        <Card className="!p-0 divide-y divide-ink-100">
          {documents.slice(0, 3).map((d) => (
            <div key={d.id} className="flex items-center gap-3 px-4 py-3">
              <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-brand-50 text-brand-600">
                <FileText className="h-4 w-4" />
              </div>
              <div className="min-w-0 flex-1">
                <p className="text-xs font-semibold text-ink-800 truncate">{d.name}</p>
                <p className="text-[11px] text-ink-400">{d.type} · {d.size}</p>
              </div>
            </div>
          ))}
        </Card>
      </div>

      <div className="px-4 mt-5">
        <SectionHeader title="Financial Snapshot" action="Details" actionTo={paths.financialCashbook} icon={<Landmark className="h-4 w-4 text-ink-400" />} />
        <Card className="flex items-center justify-between">
          <div>
            <p className="text-xs text-ink-500">Bank Balance</p>
            <p className="text-lg font-bold font-display text-ink-900 mt-0.5">₹2,14,600</p>
          </div>
          <Badge tone="success">Updated today</Badge>
        </Card>
      </div>
    </div>
  )
}
