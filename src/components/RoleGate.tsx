import type { ReactNode } from 'react'
import { useNavigate } from 'react-router-dom'
import { ShieldOff } from 'lucide-react'
import { PageHeader } from './layout/PageHeader'
import { Button } from './ui/Button'
import { EmptyState } from './ui/EmptyState'
import { useApp } from '../context/AppContext'
import { ROLES, type Role } from '../lib/types'
import { paths } from '../routes/paths'

export function RoleGate({ allow, children }: { allow: Role[]; children: ReactNode }) {
  const { user } = useApp()
  const navigate = useNavigate()

  if (allow.includes(user.role)) return <>{children}</>

  const allowedLabels = ROLES.filter((r) => allow.includes(r.id)).map((r) => r.shortLabel).join(' / ')

  return (
    <div>
      <PageHeader title="Restricted" />
      <div className="px-4 pt-10">
        <EmptyState
          icon={<ShieldOff className="h-6 w-6" />}
          title="Not part of your role"
          description={`This section is built for ${allowedLabels}. You're currently viewing as ${ROLES.find((r) => r.id === user.role)?.label}. Switch roles from Profile → Settings to explore it.`}
          action={
            <div className="flex gap-2">
              <Button variant="outline" onClick={() => navigate(-1)}>Go Back</Button>
              <Button onClick={() => navigate(paths.profileSettings)}>Switch Role</Button>
            </div>
          }
        />
      </div>
    </div>
  )
}
