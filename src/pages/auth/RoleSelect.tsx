import { useNavigate } from 'react-router-dom'
import { Users, Crown, Radar, Building2, ShieldCheck, ChevronRight } from 'lucide-react'
import { Card } from '../../components/ui/Card'
import { ROLES, type Role } from '../../lib/types'
import { useApp } from '../../context/AppContext'
import { paths } from '../../routes/paths'

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

export function RoleSelect() {
  const navigate = useNavigate()
  const { setRole, setAuthenticated } = useApp()

  function choose(role: Role) {
    setRole(role)
    setAuthenticated(true)
    navigate(paths.dashboard)
  }

  return (
    <div className="min-h-screen bg-ink-50 px-6 pb-8 pt-16">
      <h1 className="text-center font-display text-2xl font-bold text-ink-900">Continue as</h1>
      <p className="mt-1.5 text-center text-sm text-ink-500 max-w-xs mx-auto">
        Choose your role in the SHG ecosystem to see a tailored experience
      </p>

      <div className="mt-8 space-y-3">
        {ROLES.map((r) => {
          const Icon = icons[r.id]
          return (
            <Card key={r.id} interactive onClick={() => choose(r.id)} className="flex items-center gap-3">
              <div className={`flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl ${tones[r.id]}`}>
                <Icon className="h-6 w-6" />
              </div>
              <div className="min-w-0 flex-1">
                <p className="text-sm font-bold text-ink-900">{r.label}</p>
                <p className="text-xs text-ink-500 mt-0.5">{r.description}</p>
              </div>
              <ChevronRight className="h-4 w-4 shrink-0 text-ink-300" />
            </Card>
          )
        })}
      </div>
    </div>
  )
}
