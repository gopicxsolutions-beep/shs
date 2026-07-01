import { useState } from 'react'
import { ChevronDown, HelpCircle } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { cn } from '../../lib/cn'

const faqs = [
  {
    q: 'How do I add my weekly savings entry?',
    a: 'Go to Savings from the home screen, tap "Add Savings", enter the amount and mode of payment (Cash/UPI/Bank Transfer), then submit. Your SHG leader will verify the entry.',
  },
  {
    q: 'How is my loan eligibility calculated?',
    a: 'Loan eligibility is based on your savings history, repayment track record, attendance and your SHG\'s overall grading. Higher savings and on-time repayments improve your eligible amount.',
  },
  {
    q: 'What happens if I miss an EMI payment?',
    a: 'A missed EMI is marked overdue and may affect your credit score within the group. Please inform your SHG leader in advance if you expect a delay so it can be recorded properly.',
  },
  {
    q: 'How can I apply for government schemes like DAY-NRLM or MUDRA?',
    a: 'Visit the Schemes section to check your eligibility and apply directly. You can track your application status from the same screen.',
  },
  {
    q: 'Can I change my registered mobile number?',
    a: 'Yes, visit Profile > Settings and contact your SHG leader or raise a support ticket to update your mobile number after Aadhaar verification.',
  },
  {
    q: 'How do I check my SHG attendance record?',
    a: 'Open Meetings from the home screen and view your attendance history, or check the Reports section for a detailed attendance report.',
  },
]

export function FAQ() {
  const [openIndex, setOpenIndex] = useState<number | null>(0)

  return (
    <div className="pb-6">
      <PageHeader title="FAQs" subtitle="Answers to common questions" />

      <div className="px-4 mt-2 space-y-3">
        {faqs.map((item, i) => {
          const open = openIndex === i
          return (
            <Card key={item.q} className="!p-0 overflow-hidden">
              <button
                onClick={() => setOpenIndex(open ? null : i)}
                className="flex w-full items-center gap-3 px-4 py-3.5 text-left"
              >
                <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-brand-50 text-brand-600">
                  <HelpCircle className="h-4 w-4" />
                </div>
                <p className="flex-1 text-sm font-semibold text-ink-900">{item.q}</p>
                <ChevronDown className={cn('h-4 w-4 shrink-0 text-ink-400 transition-transform', open && 'rotate-180')} />
              </button>
              {open && (
                <div className="px-4 pb-4 pl-[3.75rem]">
                  <p className="text-xs leading-relaxed text-ink-500">{item.a}</p>
                </div>
              )}
            </Card>
          )
        })}
      </div>
    </div>
  )
}
