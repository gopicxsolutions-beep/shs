import type { ReactNode } from 'react'
import { useNavigate } from 'react-router-dom'
import { ArrowLeft } from 'lucide-react'
import { cn } from '../../lib/cn'

export function PageHeader({
  title,
  subtitle,
  right,
  transparent,
  onBack,
}: {
  title: string
  subtitle?: string
  right?: ReactNode
  transparent?: boolean
  onBack?: () => void
}) {
  const navigate = useNavigate()
  return (
    <header
      className={cn(
        'sticky top-0 z-30 flex items-center gap-3 px-4 pb-3 pt-[calc(env(safe-area-inset-top)+0.75rem)]',
        transparent ? 'bg-transparent' : 'bg-ink-50/90 backdrop-blur-md border-b border-ink-100',
      )}
    >
      <button
        onClick={() => (onBack ? onBack() : navigate(-1))}
        className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-white shadow-sm active:scale-95 transition"
        aria-label="Back"
      >
        <ArrowLeft className="h-4.5 w-4.5 text-ink-700" />
      </button>
      <div className="min-w-0 flex-1">
        <h1 className="truncate text-[17px] font-bold text-ink-900 font-display leading-tight">{title}</h1>
        {subtitle && <p className="truncate text-xs text-ink-500">{subtitle}</p>}
      </div>
      {right}
    </header>
  )
}
