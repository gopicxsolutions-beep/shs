import { Check, Languages } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { useApp } from '../../context/AppContext'
import type { Language } from '../../lib/types'

const languages: { id: Language; label: string; native: string }[] = [
  { id: 'en', label: 'English', native: 'English' },
  { id: 'te', label: 'Telugu', native: 'తెలుగు' },
  { id: 'hi', label: 'Hindi', native: 'हिंदी' },
]

export function LanguageSelect() {
  const { language, setLanguage } = useApp()

  return (
    <div className="pb-6">
      <PageHeader title="Language" subtitle="Choose your preferred app language" />

      <div className="px-4 mt-2 space-y-3">
        {languages.map((l) => {
          const active = language === l.id
          return (
            <Card
              key={l.id}
              interactive
              onClick={() => setLanguage(l.id)}
              className={`flex items-center gap-3 ${active ? 'border-brand-300 ring-2 ring-brand-100' : ''}`}
            >
              <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl bg-brand-50 text-brand-600">
                <Languages className="h-5.5 w-5.5" />
              </div>
              <div className="min-w-0 flex-1">
                <p className="text-sm font-bold text-ink-900">{l.native}</p>
                <p className="text-xs text-ink-500 mt-0.5">{l.label}</p>
              </div>
              {active && (
                <div className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-brand-600 text-white">
                  <Check className="h-3.5 w-3.5" />
                </div>
              )}
            </Card>
          )
        })}
      </div>
    </div>
  )
}
