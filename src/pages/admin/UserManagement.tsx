import { useState } from 'react'
import { Search, ShieldAlert, Users, Crown, Radar, Building2, ShieldCheck } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Input } from '../../components/ui/Field'
import { Avatar } from '../../components/ui/Avatar'
import { Badge } from '../../components/ui/Badge'
import type { Role } from '../../lib/types'

interface AdminUser {
  id: string
  name: string
  mobile: string
  role: Role
  village: string
  status: 'active' | 'pending'
}

const users: AdminUser[] = [
  { id: 'u1', name: 'Lakshmi Devi', mobile: '98765 43210', role: 'member', village: 'Kondapur', status: 'active' },
  { id: 'u2', name: 'Padma Reddy', mobile: '98765 11223', role: 'leader', village: 'Kondapur', status: 'active' },
  { id: 'u3', name: 'Srinivas Rao', mobile: '90011 22334', role: 'crp', village: 'Hanamkonda', status: 'active' },
  { id: 'u4', name: 'Vijaya Lakshmi', mobile: '91122 33445', role: 'clf', village: 'Warangal Rural', status: 'active' },
  { id: 'u5', name: 'Krishna Murthy', mobile: '92233 44556', role: 'admin', village: 'Head Office', status: 'active' },
  { id: 'u6', name: 'Anasuya', mobile: '90123 45671', role: 'member', village: 'Kondapur', status: 'pending' },
  { id: 'u7', name: 'Gowramma', mobile: '95678 90126', role: 'member', village: 'Narsampet', status: 'pending' },
  { id: 'u8', name: 'Ramesh Babu', mobile: '93344 55667', role: 'crp', village: 'Parkal', status: 'pending' },
]

const roleIcons: Record<Role, React.ComponentType<{ className?: string }>> = {
  member: Users,
  leader: Crown,
  crp: Radar,
  clf: Building2,
  admin: ShieldCheck,
}

const roleLabels: Record<Role, string> = {
  member: 'Member',
  leader: 'Leader',
  crp: 'CRP',
  clf: 'CLF',
  admin: 'Admin',
}

const roleTone: Record<Role, 'brand' | 'gold' | 'info' | 'neutral' | 'danger'> = {
  member: 'brand',
  leader: 'gold',
  crp: 'info',
  clf: 'neutral',
  admin: 'danger',
}

export function UserManagement() {
  const [query, setQuery] = useState('')
  const pendingCount = users.filter((u) => u.status === 'pending').length
  const filtered = users.filter(
    (u) => u.name.toLowerCase().includes(query.toLowerCase()) || u.mobile.includes(query),
  )

  return (
    <div className="pb-6">
      <PageHeader title="User Management" subtitle={`${users.length} users across all roles`} />

      {pendingCount > 0 && (
        <div className="px-4 mt-2">
          <Card className="flex items-center gap-3 bg-amber-50 border-amber-100">
            <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-amber-100 text-amber-600">
              <ShieldAlert className="h-5 w-5" />
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-bold text-amber-800">{pendingCount} accounts pending verification</p>
              <p className="text-xs text-amber-600">Aadhaar e-KYC review required</p>
            </div>
          </Card>
        </div>
      )}

      <div className="px-4 mt-4">
        <Input
          placeholder="Search by name or mobile"
          icon={<Search className="h-4 w-4" />}
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
      </div>

      <div className="px-4 mt-4 space-y-3">
        {filtered.map((u) => {
          const Icon = roleIcons[u.role]
          return (
            <Card key={u.id} className="flex items-center gap-3">
              <Avatar name={u.name} size="md" />
              <div className="min-w-0 flex-1">
                <p className="text-sm font-semibold text-ink-900 truncate">{u.name}</p>
                <p className="text-[11px] text-ink-400">{u.mobile} · {u.village}</p>
              </div>
              <div className="flex flex-col items-end gap-1.5 shrink-0">
                <Badge tone={roleTone[u.role]} dot>
                  <Icon className="h-3 w-3" /> {roleLabels[u.role]}
                </Badge>
                <Badge tone={u.status === 'active' ? 'success' : 'warning'}>{u.status}</Badge>
              </div>
            </Card>
          )
        })}
        {filtered.length === 0 && (
          <p className="text-center text-xs text-ink-400 py-8">No users found matching "{query}"</p>
        )}
      </div>
    </div>
  )
}
