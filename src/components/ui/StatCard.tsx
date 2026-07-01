import type { ReactNode } from 'react'
import { cn } from '../../lib/cn'

export function StatCard({
  label,
  value,
  icon,
  tone = 'brand',
  trend,
  className,
}: {
  label: string
  value: string
  icon?: ReactNode
  tone?: 'brand' | 'gold' | 'ink' | 'danger'
  trend?: string
  className?: string
}) {
  const toneClasses = {
    brand: 'bg-brand-600 text-white',
    gold: 'bg-gold-500 text-white',
    ink: 'bg-ink-900 text-white',
    danger: 'bg-red-500 text-white',
  }[tone]

  return (
    <div
      className={cn(
        'relative overflow-hidden rounded-2xl p-4 shadow-[var(--shadow-card)]',
        toneClasses,
        className,
      )}
    >
      <div className="absolute -right-4 -top-6 h-20 w-20 rounded-full bg-white/10" />
      <div className="absolute -right-8 bottom-0 h-16 w-16 rounded-full bg-white/10" />
      <div className="relative flex items-start justify-between">
        <div>
          <p className="text-xs font-medium text-white/75">{label}</p>
          <p className="mt-1.5 text-xl font-bold font-display leading-tight">{value}</p>
          {trend && <p className="mt-1 text-[11px] text-white/70">{trend}</p>}
        </div>
        {icon && <div className="rounded-xl bg-white/15 p-2">{icon}</div>}
      </div>
    </div>
  )
}
