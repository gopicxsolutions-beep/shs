import { cn } from '../../lib/cn'

export function ProgressBar({
  value,
  max = 100,
  tone = 'brand',
  className,
  trackClassName,
}: {
  value: number
  max?: number
  tone?: 'brand' | 'gold' | 'danger' | 'info'
  className?: string
  trackClassName?: string
}) {
  const pct = Math.max(0, Math.min(100, (value / max) * 100))
  const toneClass = {
    brand: 'bg-brand-500',
    gold: 'bg-gold-500',
    danger: 'bg-red-500',
    info: 'bg-sky-500',
  }[tone]
  return (
    <div className={cn('h-2 w-full rounded-full bg-ink-100 overflow-hidden', trackClassName)}>
      <div
        className={cn('h-full rounded-full transition-all duration-500', toneClass, className)}
        style={{ width: `${pct}%` }}
      />
    </div>
  )
}
