import { useParams } from 'react-router-dom'
import { Phone, Fingerprint, CalendarCheck2, Wallet, Landmark } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Avatar } from '../../components/ui/Avatar'
import { Badge } from '../../components/ui/Badge'
import { ProgressBar } from '../../components/ui/ProgressBar'
import { EmptyState } from '../../components/ui/EmptyState'
import { members } from '../../data/members'

export function MemberProfile() {
  const { id } = useParams()
  const member = members.find((m) => m.id === id)

  if (!member) {
    return (
      <div>
        <PageHeader title="Member" />
        <div className="px-4 pt-8">
          <EmptyState title="Member not found" />
        </div>
      </div>
    )
  }

  return (
    <div className="pb-6">
      <PageHeader title="Member Profile" />
      <div className="px-4 flex flex-col items-center pt-2">
        <Avatar name={member.name} size="xl" />
        <h1 className="mt-3 font-display text-lg font-bold text-ink-900">{member.name}</h1>
        <Badge tone="brand" className="mt-1.5">{member.role}</Badge>
      </div>

      <div className="px-4 mt-5 grid grid-cols-2 gap-3">
        <Card className="!p-3.5 text-center">
          <p className="text-lg font-bold font-display text-brand-700">₹{member.savings.toLocaleString('en-IN')}</p>
          <p className="text-[11px] text-ink-500 mt-0.5">Total Savings</p>
        </Card>
        <Card className="!p-3.5 text-center">
          <p className="text-lg font-bold font-display text-gold-600">₹{member.loanOutstanding.toLocaleString('en-IN')}</p>
          <p className="text-[11px] text-ink-500 mt-0.5">Loan Outstanding</p>
        </Card>
      </div>

      <div className="px-4 mt-4">
        <Card>
          <p className="text-xs font-bold uppercase tracking-wide text-ink-400 mb-3">Contact & KYC</p>
          <div className="space-y-3">
            <div className="flex items-center gap-3">
              <Phone className="h-4 w-4 text-ink-400" />
              <span className="text-sm text-ink-800">+91 {member.mobile}</span>
            </div>
            <div className="flex items-center gap-3">
              <Fingerprint className="h-4 w-4 text-ink-400" />
              <span className="text-sm text-ink-800">Aadhaar {member.aadhaar}</span>
            </div>
            <div className="flex items-center gap-3">
              <CalendarCheck2 className="h-4 w-4 text-ink-400" />
              <span className="text-sm text-ink-800">Joined {member.joiningDate}</span>
            </div>
          </div>
        </Card>
      </div>

      <div className="px-4 mt-4">
        <Card>
          <div className="flex items-center gap-2 mb-2">
            <CalendarCheck2 className="h-4 w-4 text-brand-600" />
            <p className="text-sm font-bold text-ink-900">Attendance</p>
          </div>
          <ProgressBar value={member.attendance} />
          <p className="text-xs text-ink-500 mt-2">{member.attendance}% meetings attended this year</p>
        </Card>
      </div>

      <div className="px-4 mt-4 grid grid-cols-2 gap-3">
        <Card className="!p-3.5 flex items-center gap-2">
          <Wallet className="h-4 w-4 text-brand-600" />
          <span className="text-xs font-semibold text-ink-700">Savings History</span>
        </Card>
        <Card className="!p-3.5 flex items-center gap-2">
          <Landmark className="h-4 w-4 text-gold-600" />
          <span className="text-xs font-semibold text-ink-700">Loan History</span>
        </Card>
      </div>
    </div>
  )
}
