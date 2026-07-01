import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { PlayCircle, FileText, Headphones, CheckCircle2, Pause } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Badge } from '../../components/ui/Badge'
import { ProgressBar } from '../../components/ui/ProgressBar'
import { Button } from '../../components/ui/Button'
import { EmptyState } from '../../components/ui/EmptyState'
import { paths } from '../../routes/paths'
import { courses, type Course } from '../../data/training'

const formatIcon: Record<Course['format'], typeof PlayCircle> = {
  Video: PlayCircle,
  PDF: FileText,
  Audio: Headphones,
}

export function CourseDetail() {
  const { id } = useParams()
  const course = courses.find((c) => c.id === id)

  if (!course) {
    return (
      <div>
        <PageHeader title="Course" />
        <div className="px-4 pt-8">
          <EmptyState title="Course not found" description="This course may have been removed or is unavailable." />
        </div>
      </div>
    )
  }

  const Icon = formatIcon[course.format]
  const [playing, setPlaying] = useState(false)
  const [progress, setProgress] = useState(course.progress)
  const complete = progress === 100

  return (
    <div className="pb-6">
      <PageHeader title="Course" subtitle={course.topic} />

      <div className="px-4 mt-2">
        <button
          onClick={() => setPlaying((p) => !p)}
          className="flex h-48 w-full items-center justify-center rounded-2xl bg-gradient-to-br from-brand-600 to-brand-800 text-white shadow-[var(--shadow-card)] transition active:scale-[0.99]"
        >
          <div className="flex flex-col items-center gap-2">
            <div className="flex h-20 w-20 items-center justify-center rounded-full bg-white/15">
              {playing ? <Pause className="h-10 w-10" /> : <Icon className="h-10 w-10" />}
            </div>
            {playing && <span className="text-xs font-semibold text-white/80">Playing {course.format.toLowerCase()}…</span>}
          </div>
        </button>
      </div>

      <div className="px-4 mt-5">
        <Card>
          <div className="flex items-start justify-between gap-2">
            <div className="min-w-0">
              <p className="text-base font-bold font-display text-ink-900">{course.title}</p>
              <p className="text-xs text-ink-500 mt-1">{course.format} · {course.duration}</p>
            </div>
            {course.certified && <Badge tone="success" className="shrink-0">Certified</Badge>}
          </div>
          <div className="mt-4">
            <div className="flex items-center justify-between mb-1.5">
              <span className="text-xs font-semibold text-ink-600">Progress</span>
              <span className="text-xs font-semibold text-ink-600">{progress}%</span>
            </div>
            <ProgressBar value={progress} tone="gold" />
          </div>
        </Card>
      </div>

      {complete && (
        <div className="px-4 mt-4">
          <Card className="flex items-center gap-3 bg-brand-50/40 border-brand-100">
            <CheckCircle2 className="h-5 w-5 text-brand-600 shrink-0" />
            <p className="text-xs text-ink-700">You've completed this course. Take the quiz to earn your certificate.</p>
          </Card>
        </div>
      )}

      <div className="px-4 mt-6 space-y-3">
        <Button
          fullWidth
          size="lg"
          onClick={() => {
            setPlaying(true)
            setProgress(100)
          }}
        >
          {progress === 0 ? 'Start Learning' : complete ? 'Review Course' : 'Continue Learning'}
        </Button>
        <Link to={paths.trainingQuiz(course.id)}>
          <Button fullWidth size="lg" variant="secondary">Start Quiz</Button>
        </Link>
      </div>
    </div>
  )
}
