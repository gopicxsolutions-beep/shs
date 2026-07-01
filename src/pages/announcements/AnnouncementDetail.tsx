import { useParams } from 'react-router-dom'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Badge } from '../../components/ui/Badge'
import { EmptyState } from '../../components/ui/EmptyState'
import { announcements, type Announcement } from '../../data/announcements'

const categoryTone: Record<Announcement['category'], 'neutral' | 'info' | 'gold' | 'brand'> = {
  Circular: 'neutral',
  Meeting: 'info',
  Training: 'gold',
  Scheme: 'brand',
}

export function AnnouncementDetail() {
  const { id } = useParams()
  const announcement = announcements.find((a) => a.id === id)

  if (!announcement) {
    return (
      <div>
        <PageHeader title="Announcement" />
        <div className="px-4 pt-8">
          <EmptyState title="Announcement not found" description="This announcement may have been removed." />
        </div>
      </div>
    )
  }

  return (
    <div className="pb-6">
      <PageHeader title="Announcement" subtitle={announcement.date} />

      <div className="px-4 mt-2">
        <Card>
          <div className="flex items-start justify-between gap-2">
            <p className="text-base font-bold font-display text-ink-900">{announcement.title}</p>
            <Badge tone={categoryTone[announcement.category]} className="shrink-0">{announcement.category}</Badge>
          </div>
          <p className="text-xs text-ink-400 mt-2">{announcement.date}</p>
          <p className="text-sm text-ink-700 mt-4 leading-relaxed">{announcement.body}</p>
        </Card>
      </div>
    </div>
  )
}
