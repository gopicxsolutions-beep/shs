import { useState } from 'react'
import { Link } from 'react-router-dom'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Badge } from '../../components/ui/Badge'
import { SegmentedTabs } from '../../components/ui/SegmentedTabs'
import { EmptyState } from '../../components/ui/EmptyState'
import { paths } from '../../routes/paths'
import { announcements, type Announcement } from '../../data/announcements'

const categoryTone: Record<Announcement['category'], 'neutral' | 'info' | 'gold' | 'brand'> = {
  Circular: 'neutral',
  Meeting: 'info',
  Training: 'gold',
  Scheme: 'brand',
}

const categories = ['All', 'Circular', 'Meeting', 'Training', 'Scheme']

export function AnnouncementsHome() {
  const [tab, setTab] = useState('All')
  const filtered = tab === 'All' ? announcements : announcements.filter((a) => a.category === tab)
  const unreadCount = announcements.filter((a) => !a.read).length

  return (
    <div className="pb-6">
      <PageHeader title="Announcements" subtitle={unreadCount > 0 ? `${unreadCount} unread` : 'All caught up'} />

      <div className="px-4 mt-2">
        <SegmentedTabs options={categories.map((c) => ({ value: c, label: c }))} value={tab} onChange={setTab} />
      </div>

      <div className="px-4 mt-4">
        {filtered.length === 0 ? (
          <EmptyState title="No announcements" description="Nothing to show in this category yet." />
        ) : (
          <Card className="!p-0 divide-y divide-ink-100">
            {filtered.map((a) => (
              <Link key={a.id} to={paths.announcementDetail(a.id)} className="flex items-start gap-2 px-4 py-3">
                {!a.read && <span className="mt-1.5 h-1.5 w-1.5 shrink-0 rounded-full bg-brand-500" />}
                <div className={`min-w-0 flex-1 ${a.read ? 'ml-3.5' : ''}`}>
                  <div className="flex items-start justify-between gap-2">
                    <p className={`text-xs truncate ${a.read ? 'font-medium text-ink-700' : 'font-semibold text-ink-900'}`}>{a.title}</p>
                    <Badge tone={categoryTone[a.category]} className="shrink-0">{a.category}</Badge>
                  </div>
                  <p className="text-[11px] text-ink-400 mt-1">{a.date}</p>
                </div>
              </Link>
            ))}
          </Card>
        )}
      </div>
    </div>
  )
}
