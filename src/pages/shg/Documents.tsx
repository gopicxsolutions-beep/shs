import { FileText, Image, Download, Plus } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
import { documents } from '../../data/shg'

export function Documents() {
  return (
    <div className="pb-6">
      <PageHeader
        title="Documents"
        subtitle={`${documents.length} files`}
        right={
          <Button size="icon" variant="secondary">
            <Plus className="h-4.5 w-4.5" />
          </Button>
        }
      />
      <div className="px-4 mt-2 space-y-3">
        {documents.map((d) => (
          <Card key={d.id} className="flex items-center gap-3">
            <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-brand-50 text-brand-600">
              {d.type === 'IMG' ? <Image className="h-5 w-5" /> : <FileText className="h-5 w-5" />}
            </div>
            <div className="min-w-0 flex-1">
              <p className="text-sm font-semibold text-ink-900 truncate">{d.name}</p>
              <p className="text-xs text-ink-500 mt-0.5">{d.type} · {d.size} · {d.date}</p>
            </div>
            <button className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-ink-100 text-ink-600 active:scale-95 transition">
              <Download className="h-4 w-4" />
            </button>
          </Card>
        ))}
      </div>
    </div>
  )
}
