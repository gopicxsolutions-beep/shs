import { useState } from 'react'
import { Plus, FileCog } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
import { Badge } from '../../components/ui/Badge'
import { useData } from '../../context/DataContext'

export function SchemeManagement() {
  const { schemes: initialSchemes } = useData()
  const [activeMap, setActiveMap] = useState<Record<string, boolean>>(
    () => Object.fromEntries(initialSchemes.map((s) => [s.id, true])),
  )

  return (
    <div className="pb-6">
      <PageHeader title="Scheme Management" subtitle={`${initialSchemes.length} schemes configured`} />

      <div className="px-4 mt-2">
        <Button fullWidth size="lg" icon={<Plus className="h-4 w-4" />}>
          Add Scheme
        </Button>
      </div>

      <div className="px-4 mt-4 space-y-3">
        {initialSchemes.map((s) => {
          const active = activeMap[s.id]
          return (
            <Card key={s.id}>
              <div className="flex items-start gap-3">
                <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-gold-50 text-gold-600">
                  <FileCog className="h-5 w-5" />
                </div>
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <p className="text-sm font-bold text-ink-900">{s.name}</p>
                    <Badge tone={active ? 'success' : 'neutral'}>{active ? 'Active' : 'Inactive'}</Badge>
                  </div>
                  <p className="text-xs text-ink-500 mt-0.5">{s.fullName}</p>
                  <p className="text-xs text-ink-600 mt-2 leading-relaxed">{s.benefit}</p>
                </div>
              </div>
              <div className="flex items-center gap-2 mt-3">
                <Button variant="outline" size="sm" className="flex-1">Edit</Button>
                <Button
                  variant={active ? 'danger' : 'secondary'}
                  size="sm"
                  className="flex-1"
                  onClick={() => setActiveMap((m) => ({ ...m, [s.id]: !m[s.id] }))}
                >
                  {active ? 'Deactivate' : 'Activate'}
                </Button>
              </div>
            </Card>
          )
        })}
      </div>
    </div>
  )
}
