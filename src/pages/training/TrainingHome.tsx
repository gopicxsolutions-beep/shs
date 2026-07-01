import { useState } from 'react'
import { Link } from 'react-router-dom'
import { PlayCircle, FileText, Headphones, Award } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Badge } from '../../components/ui/Badge'
import { ProgressBar } from '../../components/ui/ProgressBar'
import { SegmentedTabs } from '../../components/ui/SegmentedTabs'
import { SectionHeader } from '../../components/ui/SectionHeader'
import { paths } from '../../routes/paths'
import { courses, type Course } from '../../data/training'

const topics = ['All', 'Financial Literacy', 'Entrepreneurship', 'Digital Payments', 'Marketing']

const formatIcon: Record<Course['format'], typeof PlayCircle> = {
  Video: PlayCircle,
  PDF: FileText,
  Audio: Headphones,
}

export function TrainingHome() {
  const [tab, setTab] = useState('All')
  const filtered = tab === 'All' ? courses : courses.filter((c) => c.topic === tab)

  return (
    <div className="pb-6">
      <PageHeader title="Training & Capacity Building" subtitle={`${courses.length} courses available`} />

      <div className="px-4 mt-2">
        <SegmentedTabs
          options={topics.map((t) => ({ value: t, label: t }))}
          value={tab}
          onChange={setTab}
          className="overflow-x-auto"
        />
      </div>

      <div className="px-4 mt-5">
        <SectionHeader title="Certificates" action="View all" actionTo={paths.trainingCertificates} icon={<Award className="h-4 w-4 text-ink-400" />} />
      </div>

      <div className="px-4 -mt-2 space-y-3">
        {filtered.map((c) => {
          const Icon = formatIcon[c.format]
          return (
            <Link key={c.id} to={paths.trainingDetail(c.id)}>
              <Card interactive className="flex gap-3">
                <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-xl bg-brand-50 text-brand-600">
                  <Icon className="h-6 w-6" />
                </div>
                <div className="min-w-0 flex-1">
                  <div className="flex items-start justify-between gap-2">
                    <p className="text-sm font-semibold text-ink-900 truncate">{c.title}</p>
                    {c.certified && <Badge tone="success" className="shrink-0">Certified</Badge>}
                  </div>
                  <p className="text-xs text-ink-500 mt-0.5">{c.topic} · {c.duration}</p>
                  <ProgressBar value={c.progress} tone="gold" className="mt-2" />
                </div>
              </Card>
            </Link>
          )
        })}
      </div>
    </div>
  )
}
