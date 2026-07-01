import { useState } from 'react'
import { Users, Crown, Radar, Building2, ShieldCheck, Check, Bell, MessageSquareText, CalendarClock, FileText, Lock } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { ListRow } from '../../components/ui/ListRow'
import { useApp } from '../../context/AppContext'
import { ROLES, type Role } from '../../lib/types'

const icons: Record<Role, React.ComponentType<{ className?: string }>> = {
  member: Users,
  leader: Crown,
  crp: Radar,
  clf: Building2,
  admin: ShieldCheck,
}

const tones: Record<Role, string> = {
  member: 'bg-brand-50 text-brand-600',
  leader: 'bg-gold-50 text-gold-600',
  crp: 'bg-sky-50 text-sky-600',
  clf: 'bg-violet-50 text-violet-600',
  admin: 'bg-rose-50 text-rose-600',
}

function Toggle({ checked, onChange }: { checked: boolean; onChange: (v: boolean) => void }) {
  return (
    <button
      onClick={() => onChange(!checked)}
      className={`relative h-6 w-11 shrink-0 rounded-full transition ${checked ? 'bg-brand-600' : 'bg-ink-200'}`}
      aria-pressed={checked}
    >
      <span
        className={`absolute top-0.5 h-5 w-5 rounded-full bg-white shadow-sm transition-transform ${checked ? 'translate-x-[22px]' : 'translate-x-0.5'}`}
      />
    </button>
  )
}

export function Settings() {
  const { user, setRole } = useApp()
  const [notifications, setNotifications] = useState({
    meetings: true,
    payments: true,
    schemes: false,
    chat: true,
  })

  return (
    <div className="pb-6">
      <PageHeader title="Settings" />

      <div className="px-4 mt-2">
        <p className="text-xs font-bold uppercase tracking-wide text-ink-400 mb-2">Switch Role</p>
        <p className="text-xs text-ink-500 mb-3">
          This is a demo app — switching roles changes your entire app experience.
        </p>
        <div className="space-y-3">
          {ROLES.map((r) => {
            const Icon = icons[r.id]
            const active = user.role === r.id
            return (
              <Card
                key={r.id}
                interactive
                onClick={() => setRole(r.id)}
                className={`flex items-center gap-3 ${active ? 'border-brand-300 ring-2 ring-brand-100' : ''}`}
              >
                <div className={`flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl ${tones[r.id]}`}>
                  <Icon className="h-5.5 w-5.5" />
                </div>
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-bold text-ink-900">{r.label}</p>
                  <p className="text-xs text-ink-500 mt-0.5">{r.description}</p>
                </div>
                {active && (
                  <div className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-brand-600 text-white">
                    <Check className="h-3.5 w-3.5" />
                  </div>
                )}
              </Card>
            )
          })}
        </div>
      </div>

      <div className="px-4 mt-6">
        <p className="text-xs font-bold uppercase tracking-wide text-ink-400 mb-2">Notifications</p>
        <Card className="!p-0 divide-y divide-ink-100">
          <div className="flex items-center gap-3 px-4 py-3.5">
            <CalendarClock className="h-4.5 w-4.5 text-ink-400 shrink-0" />
            <p className="flex-1 text-sm font-semibold text-ink-800">Meeting reminders</p>
            <Toggle checked={notifications.meetings} onChange={(v) => setNotifications((n) => ({ ...n, meetings: v }))} />
          </div>
          <div className="flex items-center gap-3 px-4 py-3.5">
            <Bell className="h-4.5 w-4.5 text-ink-400 shrink-0" />
            <p className="flex-1 text-sm font-semibold text-ink-800">Payment & EMI alerts</p>
            <Toggle checked={notifications.payments} onChange={(v) => setNotifications((n) => ({ ...n, payments: v }))} />
          </div>
          <div className="flex items-center gap-3 px-4 py-3.5">
            <FileText className="h-4.5 w-4.5 text-ink-400 shrink-0" />
            <p className="flex-1 text-sm font-semibold text-ink-800">Scheme updates</p>
            <Toggle checked={notifications.schemes} onChange={(v) => setNotifications((n) => ({ ...n, schemes: v }))} />
          </div>
          <div className="flex items-center gap-3 px-4 py-3.5">
            <MessageSquareText className="h-4.5 w-4.5 text-ink-400 shrink-0" />
            <p className="flex-1 text-sm font-semibold text-ink-800">Chat support replies</p>
            <Toggle checked={notifications.chat} onChange={(v) => setNotifications((n) => ({ ...n, chat: v }))} />
          </div>
        </Card>
      </div>

      <div className="px-4 mt-6">
        <p className="text-xs font-bold uppercase tracking-wide text-ink-400 mb-2">About</p>
        <Card className="!p-0 divide-y divide-ink-100">
          <div className="px-4">
            <ListRow
              leading={<div className="flex h-9 w-9 items-center justify-center rounded-lg bg-ink-100 text-ink-500"><Lock className="h-4 w-4" /></div>}
              title="Privacy Policy"
              onClick={() => {}}
            />
          </div>
          <div className="px-4">
            <ListRow
              leading={<div className="flex h-9 w-9 items-center justify-center rounded-lg bg-ink-100 text-ink-500"><FileText className="h-4 w-4" /></div>}
              title="Terms & Conditions"
              onClick={() => {}}
            />
          </div>
        </Card>
        <p className="text-center text-[11px] text-ink-400 mt-4">SHG Saathi · v1.0.0</p>
      </div>
    </div>
  )
}
