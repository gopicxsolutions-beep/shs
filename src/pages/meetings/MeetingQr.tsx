import { useState } from 'react'
import { QrCode, CheckCircle2, ScanLine } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Button } from '../../components/ui/Button'
import { EmptyState } from '../../components/ui/EmptyState'
import { useData } from '../../context/DataContext'

export function MeetingQr() {
  const { meetings } = useData()
  const [scanned, setScanned] = useState(false)
  const meeting = meetings.find((m) => m.status === 'upcoming')

  if (!meeting) {
    return (
      <div>
        <PageHeader title="QR Attendance" />
        <div className="px-4 pt-8"><EmptyState title="No upcoming meeting" description="Check back once a meeting is scheduled." /></div>
      </div>
    )
  }

  return (
    <div className="pb-6">
      <PageHeader title="QR Attendance" />
      <div className="px-6 mt-6 flex flex-col items-center text-center">
        <p className="text-sm font-semibold text-ink-800">{meeting.agenda}</p>
        <p className="text-xs text-ink-500 mt-0.5">{meeting.date} · {meeting.time} · {meeting.venue}</p>

        <div className="relative mt-8 flex h-64 w-64 items-center justify-center rounded-3xl border-2 border-dashed border-brand-300 bg-brand-50/40">
          {scanned ? (
            <div className="flex flex-col items-center gap-2 text-brand-600">
              <CheckCircle2 className="h-16 w-16" />
              <p className="text-sm font-bold">Checked in!</p>
            </div>
          ) : (
            <>
              <QrCode className="h-28 w-28 text-brand-300" />
              <ScanLine className="absolute h-64 w-full animate-pulse text-brand-500/60" />
            </>
          )}
        </div>

        <p className="mt-6 text-xs text-ink-500 max-w-[240px]">
          {scanned ? 'Your attendance has been recorded successfully.' : 'Point your camera at the QR code displayed by your SHG leader'}
        </p>

        {!scanned && (
          <Button className="mt-8" size="lg" onClick={() => setScanned(true)}>
            Simulate Scan
          </Button>
        )}
      </div>
    </div>
  )
}
