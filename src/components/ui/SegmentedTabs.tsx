import { cn } from '../../lib/cn'

export function SegmentedTabs({
  options,
  value,
  onChange,
  className,
}: {
  options: { value: string; label: string }[]
  value: string
  onChange: (v: string) => void
  className?: string
}) {
  return (
    <div className={cn('flex rounded-xl bg-ink-100 p-1', className)}>
      {options.map((opt) => (
        <button
          key={opt.value}
          onClick={() => onChange(opt.value)}
          className={cn(
            'flex-1 rounded-lg py-2 text-xs font-semibold transition whitespace-nowrap px-2',
            value === opt.value ? 'bg-white text-brand-700 shadow-sm' : 'text-ink-500',
          )}
        >
          {opt.label}
        </button>
      ))}
    </div>
  )
}
