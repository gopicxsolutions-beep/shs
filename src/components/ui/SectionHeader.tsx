import type { ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { ChevronRight } from 'lucide-react'

export function SectionHeader({
  title,
  subtitle,
  action,
  actionTo,
  icon,
}: {
  title: string
  subtitle?: string
  action?: string
  actionTo?: string
  icon?: ReactNode
}) {
  return (
    <div className="flex items-end justify-between mb-3">
      <div className="flex items-center gap-2">
        {icon}
        <div>
          <h2 className="text-[15px] font-bold text-ink-900 font-display">{title}</h2>
          {subtitle && <p className="text-xs text-ink-500 mt-0.5">{subtitle}</p>}
        </div>
      </div>
      {action && actionTo && (
        <Link
          to={actionTo}
          className="flex items-center gap-0.5 text-xs font-semibold text-brand-600 hover:text-brand-700"
        >
          {action}
          <ChevronRight className="h-3.5 w-3.5" />
        </Link>
      )}
    </div>
  )
}
