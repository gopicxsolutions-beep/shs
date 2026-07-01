import { Link, useNavigate } from 'react-router-dom'
import { Settings2, Languages, MapPin, Building2, ChevronRight, LogOut } from 'lucide-react'
import { Card } from '../../components/ui/Card'
import { Badge } from '../../components/ui/Badge'
import { Avatar } from '../../components/ui/Avatar'
import { Button } from '../../components/ui/Button'
import { paths } from '../../routes/paths'
import { useApp } from '../../context/AppContext'
import { ROLES } from '../../lib/types'

export function Profile() {
  const navigate = useNavigate()
  const { user, setAuthenticated } = useApp()
  const roleInfo = ROLES.find((r) => r.id === user.role)

  function logout() {
    setAuthenticated(false)
    navigate(paths.splash)
  }

  return (
    <div className="pb-6">
      <div className="bg-gradient-to-br from-brand-700 to-brand-500 px-4 pb-8 pt-[calc(env(safe-area-inset-top)+1.25rem)] text-white">
        <div className="flex items-center gap-3">
          <Avatar name={user.name} size="xl" className="!bg-white/15 !text-white" />
          <div className="min-w-0 flex-1">
            <h1 className="font-display text-lg font-bold truncate">{user.name}</h1>
            <p className="text-xs text-white/75 mt-0.5">{user.mobile}</p>
            <div className="mt-2">
              <Badge tone="gold">{roleInfo?.label ?? user.role}</Badge>
            </div>
          </div>
        </div>
      </div>

      <div className="px-4 -mt-4">
        <Card className="flex items-center gap-3">
          <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl bg-brand-50 text-brand-600">
            <Building2 className="h-5.5 w-5.5" />
          </div>
          <div className="min-w-0 flex-1">
            <p className="text-sm font-bold text-ink-900 truncate">{user.shgName}</p>
            <p className="flex items-center gap-1 text-xs text-ink-500 mt-0.5">
              <MapPin className="h-3 w-3 shrink-0" /> {user.village}
            </p>
          </div>
        </Card>
      </div>

      <div className="px-4 mt-5 space-y-3">
        <Link to={paths.profileSettings}>
          <Card interactive className="flex items-center gap-3">
            <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl bg-ink-100 text-ink-600">
              <Settings2 className="h-5 w-5" />
            </div>
            <div className="min-w-0 flex-1">
              <p className="text-sm font-bold text-ink-900">Settings</p>
              <p className="text-xs text-ink-500 mt-0.5">Switch role, notifications & more</p>
            </div>
            <ChevronRight className="h-4 w-4 shrink-0 text-ink-300" />
          </Card>
        </Link>

        <Link to={paths.profileLanguage}>
          <Card interactive className="flex items-center gap-3">
            <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl bg-sky-50 text-sky-600">
              <Languages className="h-5 w-5" />
            </div>
            <div className="min-w-0 flex-1">
              <p className="text-sm font-bold text-ink-900">Language</p>
              <p className="text-xs text-ink-500 mt-0.5">English · తెలుగు · हिंदी</p>
            </div>
            <ChevronRight className="h-4 w-4 shrink-0 text-ink-300" />
          </Card>
        </Link>
      </div>

      <div className="px-4 mt-6">
        <Button variant="danger" fullWidth size="lg" icon={<LogOut className="h-4 w-4" />} onClick={logout}>
          Logout
        </Button>
      </div>
    </div>
  )
}
