import type { InputHTMLAttributes, ReactNode, TextareaHTMLAttributes } from 'react'
import { cn } from '../../lib/cn'

interface FieldWrapProps {
  label?: string
  hint?: string
  icon?: ReactNode
  suffix?: ReactNode
}

export function Input({
  label,
  hint,
  icon,
  suffix,
  className,
  ...props
}: FieldWrapProps & InputHTMLAttributes<HTMLInputElement>) {
  return (
    <label className="block">
      {label && <span className="mb-1.5 block text-xs font-semibold text-ink-600">{label}</span>}
      <div className="flex items-center gap-2 rounded-xl border border-ink-200 bg-white px-3.5 focus-within:border-brand-500 focus-within:ring-2 focus-within:ring-brand-100 transition">
        {icon && <span className="text-ink-400">{icon}</span>}
        <input
          className={cn('h-11 w-full bg-transparent text-sm text-ink-900 outline-none placeholder:text-ink-400', className)}
          {...props}
        />
        {suffix}
      </div>
      {hint && <span className="mt-1 block text-[11px] text-ink-400">{hint}</span>}
    </label>
  )
}

export function Textarea({
  label,
  hint,
  className,
  ...props
}: FieldWrapProps & TextareaHTMLAttributes<HTMLTextAreaElement>) {
  return (
    <label className="block">
      {label && <span className="mb-1.5 block text-xs font-semibold text-ink-600">{label}</span>}
      <div className="rounded-xl border border-ink-200 bg-white px-3.5 py-2.5 focus-within:border-brand-500 focus-within:ring-2 focus-within:ring-brand-100 transition">
        <textarea
          className={cn('w-full bg-transparent text-sm text-ink-900 outline-none placeholder:text-ink-400 resize-none', className)}
          {...props}
        />
      </div>
      {hint && <span className="mt-1 block text-[11px] text-ink-400">{hint}</span>}
    </label>
  )
}
