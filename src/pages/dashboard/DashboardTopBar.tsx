import { Link } from 'react-router-dom'
import { Bell, ChevronsUpDown } from 'lucide-react'
import { Avatar } from '../../components/ui/Avatar'
import { useApp } from '../../context/AppContext'
import { ROLES } from '../../lib/types'
import { paths } from '../../routes/paths'
import { announcements } from '../../data/announcements'

export function DashboardTopBar() {
  const { user } = useApp()
  const roleInfo = ROLES.find((r) => r.id === user.role)!
  const unread = announcements.filter((a) => !a.read).length

  return (
    <div className="bg-gradient-to-br from-brand-700 via-brand-600 to-brand-500 px-5 pb-16 pt-[calc(env(safe-area-inset-top)+1.25rem)] text-white">
      <div className="flex items-center justify-between">
        <div>
          <Link to={paths.profileSettings} className="inline-flex items-center gap-1 rounded-full bg-white/10 px-2 py-0.5 -ml-2 active:scale-95 transition">
            <span className="text-xs text-white/80">{roleInfo.label}</span>
            <ChevronsUpDown className="h-3 w-3 text-white/60" />
          </Link>
          <h1 className="font-display text-lg font-bold mt-1">Namaste, {user.name.split(' ')[0]} 🙏</h1>
          <p className="text-xs text-white/70 mt-0.5">{user.shgName}</p>
        </div>
        <div className="flex items-center gap-2.5">
          <Link
            to={paths.announcements}
            className="relative flex h-10 w-10 items-center justify-center rounded-full bg-white/15 backdrop-blur active:scale-95 transition"
          >
            <Bell className="h-4.5 w-4.5" />
            {unread > 0 && (
              <span className="absolute right-1.5 top-1.5 h-2 w-2 rounded-full bg-gold-400 ring-2 ring-brand-600" />
            )}
          </Link>
          <Link to={paths.profile}>
            <Avatar name={user.name} size="md" className="ring-2 ring-white/40" />
          </Link>
        </div>
      </div>
    </div>
  )
}
