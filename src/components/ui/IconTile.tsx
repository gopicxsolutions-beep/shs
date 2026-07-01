import type { ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { cn } from '../../lib/cn'

const tones = {
  brand: 'bg-brand-50 text-brand-600',
  gold: 'bg-gold-50 text-gold-600',
  sky: 'bg-sky-50 text-sky-600',
  rose: 'bg-rose-50 text-rose-600',
  violet: 'bg-violet-50 text-violet-600',
  ink: 'bg-ink-100 text-ink-600',
}

export function IconTile({
  to,
  icon,
  label,
  tone = 'brand',
  badge,
}: {
  to: string
  icon: ReactNode
  label: string
  tone?: keyof typeof tones
  badge?: string
}) {
  return (
    <Link to={to} className="flex flex-col items-center gap-1.5 text-center active:scale-95 transition">
      <div className={cn('relative flex h-13 w-13 items-center justify-center rounded-2xl', tones[tone])}>
        {icon}
        {badge && (
          <span className="absolute -top-1 -right-1 flex h-4 min-w-4 items-center justify-center rounded-full bg-red-500 px-1 text-[9px] font-bold text-white">
            {badge}
          </span>
        )}
      </div>
      <span className="text-[11px] font-medium text-ink-700 leading-tight w-16">{label}</span>
    </Link>
  )
}
