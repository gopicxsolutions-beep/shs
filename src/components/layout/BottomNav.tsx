import { NavLink } from 'react-router-dom'
import { Home, Users, Building2, Grid2x2, Store, UserRound } from 'lucide-react'
import { cn } from '../../lib/cn'
import { useApp } from '../../context/AppContext'

export function BottomNav() {
  const { user } = useApp()
  const isOversightRole = user.role === 'crp' || user.role === 'clf' || user.role === 'admin'

  const items = [
    { to: '/app/dashboard', label: 'Home', icon: Home },
    isOversightRole
      ? { to: '/app/shg', label: 'SHGs', icon: Building2 }
      : { to: '/app/shg', label: 'My SHG', icon: Users },
    { to: '/app/services', label: 'Services', icon: Grid2x2, center: true },
    { to: '/app/marketplace', label: 'Market', icon: Store },
    { to: '/app/profile', label: 'Profile', icon: UserRound },
  ]

  return (
    <nav className="sticky bottom-0 z-40 border-t border-ink-100 bg-white/95 backdrop-blur-md pb-[env(safe-area-inset-bottom)] shadow-[var(--shadow-nav)]">
      <div className="flex items-center justify-between px-2">
        {items.map(({ to, label, icon: Icon, center }) => (
          <NavLink
            key={to}
            to={to}
            className={({ isActive }) =>
              cn(
                'flex flex-1 flex-col items-center gap-0.5 py-2.5 text-[10px] font-semibold transition',
                center && '-mt-5',
                isActive ? 'text-brand-600' : 'text-ink-400',
              )
            }
          >
            {({ isActive }) =>
              center ? (
                <>
                  <span
                    className={cn(
                      'flex h-13 w-13 items-center justify-center rounded-2xl shadow-[0_8px_20px_-6px_rgba(14,138,102,0.6)] transition',
                      isActive ? 'bg-brand-700' : 'bg-brand-600',
                    )}
                  >
                    <Icon className="h-6 w-6 text-white" strokeWidth={2.2} />
                  </span>
                  <span className={isActive ? 'text-brand-600' : 'text-ink-500'}>{label}</span>
                </>
              ) : (
                <>
                  <Icon className="h-5.5 w-5.5" strokeWidth={isActive ? 2.4 : 2} />
                  <span>{label}</span>
                </>
              )
            }
          </NavLink>
        ))}
      </div>
    </nav>
  )
}
