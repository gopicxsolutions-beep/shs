import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { CheckCircle2, Award } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
import { Badge } from '../../components/ui/Badge'
import { paths } from '../../routes/paths'
import { courses } from '../../data/training'
import { cn } from '../../lib/cn'

interface Question {
  q: string
  options: string[]
  answer: number
}

const questions: Question[] = [
  {
    q: 'What does UPI stand for?',
    options: ['Unified Payments Interface', 'Universal Pay Instrument', 'United Payment India', 'Unified Purchase Invoice'],
    answer: 0,
  },
  {
    q: 'Which of these is required to make a UPI payment?',
    options: ['A UPI PIN', 'A cheque book', 'A demand draft', 'A passbook'],
    answer: 0,
  },
  {
    q: 'What is a good practice for saving regularly?',
    options: [
      'Save only when there is money left over',
      'Set aside a fixed amount every week or month',
      'Borrow to save more',
      'Skip savings during festivals',
    ],
    answer: 1,
  },
]

export function Quiz() {
  const { id } = useParams()
  const navigate = useNavigate()
  const course = courses.find((c) => c.id === id)
  const [answers, setAnswers] = useState<(number | null)[]>(Array(questions.length).fill(null))
  const [submitted, setSubmitted] = useState(false)

  const score = answers.reduce<number>((acc, a, i) => acc + (a === questions[i].answer ? 1 : 0), 0)
  const pct = Math.round((score / questions.length) * 100)
  const allAnswered = answers.every((a) => a !== null)

  if (submitted) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center px-8 text-center">
        <div className="flex h-16 w-16 items-center justify-center rounded-full bg-brand-50 text-brand-600">
          <CheckCircle2 className="h-9 w-9" />
        </div>
        <h1 className="mt-5 font-display text-xl font-bold text-ink-900">Quiz complete!</h1>
        <p className="mt-1.5 text-sm text-ink-500">
          You scored {score} out of {questions.length} ({pct}%)
          {course ? ` on "${course.title}"` : ''}.
        </p>
        {pct >= 60 ? (
          <Button className="mt-8" fullWidth size="lg" icon={<Award className="h-4 w-4" />} onClick={() => navigate(paths.trainingCertificates)}>
            Get Certificate
          </Button>
        ) : (
          <Button className="mt-8" fullWidth size="lg" variant="secondary" onClick={() => setSubmitted(false)}>
            Retake Quiz
          </Button>
        )}
        <Button className="mt-3" fullWidth size="lg" variant="ghost" onClick={() => navigate(paths.training)}>
          Back to Training
        </Button>
      </div>
    )
  }

  return (
    <div className="pb-6">
      <PageHeader title="Quiz" subtitle={course?.title} />

      <div className="px-4 mt-2 space-y-4">
        {questions.map((q, qi) => (
          <Card key={qi}>
            <div className="flex items-center gap-2 mb-3">
              <Badge tone="brand">Q{qi + 1}</Badge>
              <p className="text-sm font-semibold text-ink-900">{q.q}</p>
            </div>
            <div className="space-y-2">
              {q.options.map((opt, oi) => {
                const selected = answers[qi] === oi
                return (
                  <button
                    key={oi}
                    type="button"
                    onClick={() =>
                      setAnswers((prev) => {
                        const next = [...prev]
                        next[qi] = oi
                        return next
                      })
                    }
                    className={cn(
                      'flex w-full items-center gap-2.5 rounded-xl border px-3.5 py-2.5 text-left text-xs font-medium transition active:scale-[0.98]',
                      selected ? 'border-brand-500 bg-brand-50 text-brand-700' : 'border-ink-200 text-ink-700',
                    )}
                  >
                    <span
                      className={cn(
                        'flex h-4 w-4 shrink-0 items-center justify-center rounded-full border',
                        selected ? 'border-brand-600 bg-brand-600' : 'border-ink-300',
                      )}
                    >
                      {selected && <span className="h-1.5 w-1.5 rounded-full bg-white" />}
                    </span>
                    {opt}
                  </button>
                )
              })}
            </div>
          </Card>
        ))}

        <Button fullWidth size="lg" disabled={!allAnswered} onClick={() => setSubmitted(true)}>
          Submit
        </Button>
      </div>
    </div>
  )
}
