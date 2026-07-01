import type { HTMLAttributes } from 'react'
import { cn } from '../../lib/cn'

interface CardProps extends HTMLAttributes<HTMLDivElement> {
  padded?: boolean
  interactive?: boolean
}

export function Card({ className, padded = true, interactive = false, ...props }: CardProps) {
  return (
    <div
      className={cn(
        'rounded-2xl bg-white shadow-[var(--shadow-card)] border border-ink-100/60',
        padded && 'p-4',
        interactive && 'transition active:scale-[0.98] active:shadow-sm cursor-pointer',
        className,
      )}
      {...props}
    />
  )
}
