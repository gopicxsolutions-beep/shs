import { useState } from 'react'
import { Check, X } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
import { Avatar } from '../../components/ui/Avatar'
import { members } from '../../data/members'

export function MeetingAttendance() {
  const [present, setPresent] = useState<Record<string, boolean>>(
    Object.fromEntries(members.map((m) => [m.id, true])),
  )
  const count = Object.values(present).filter(Boolean).length

  return (
    <div className="pb-6">
      <PageHeader title="Digital Attendance" subtitle={`${count} of ${members.length} present`} />
      <div className="px-4 mt-2">
        <Card className="!p-0 divide-y divide-ink-100">
          {members.map((m) => (
            <div key={m.id} className="flex items-center gap-3 px-4 py-3">
              <Avatar name={m.name} size="sm" />
              <div className="min-w-0 flex-1">
                <p className="text-xs font-semibold text-ink-800 truncate">{m.name}</p>
                <p className="text-[11px] text-ink-400">{m.role}</p>
              </div>
              <div className="flex gap-1.5">
                <button
                  onClick={() => setPresent((p) => ({ ...p, [m.id]: true }))}
                  className={`flex h-8 w-8 items-center justify-center rounded-full transition ${present[m.id] ? 'bg-brand-600 text-white' : 'bg-ink-100 text-ink-400'}`}
                >
                  <Check className="h-4 w-4" />
                </button>
                <button
                  onClick={() => setPresent((p) => ({ ...p, [m.id]: false }))}
                  className={`flex h-8 w-8 items-center justify-center rounded-full transition ${!present[m.id] ? 'bg-red-500 text-white' : 'bg-ink-100 text-ink-400'}`}
                >
                  <X className="h-4 w-4" />
                </button>
              </div>
            </div>
          ))}
        </Card>
      </div>
      <div className="px-4 mt-5">
        <Button fullWidth size="lg">Save Attendance</Button>
      </div>
    </div>
  )
}
