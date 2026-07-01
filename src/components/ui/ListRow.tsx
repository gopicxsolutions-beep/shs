import type { ReactNode } from 'react'
import { ChevronRight } from 'lucide-react'
import { cn } from '../../lib/cn'

export function ListRow({
  leading,
  title,
  subtitle,
  trailing,
  onClick,
  chevron = true,
  className,
}: {
  leading?: ReactNode
  title: ReactNode
  subtitle?: ReactNode
  trailing?: ReactNode
  onClick?: () => void
  chevron?: boolean
  className?: string
}) {
  const Comp = onClick ? 'button' : 'div'
  return (
    <Comp
      onClick={onClick}
      className={cn(
        'flex w-full items-center gap-3 py-3 text-left',
        onClick && 'active:opacity-70 transition',
        className,
      )}
    >
      {leading}
      <div className="min-w-0 flex-1">
        <p className="truncate text-sm font-semibold text-ink-900">{title}</p>
        {subtitle && <p className="truncate text-xs text-ink-500 mt-0.5">{subtitle}</p>}
      </div>
      {trailing}
      {onClick && chevron && <ChevronRight className="h-4 w-4 shrink-0 text-ink-300" />}
    </Comp>
  )
}
