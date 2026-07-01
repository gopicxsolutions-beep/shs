import { useState, type ReactNode } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { ShieldOff, Eye, X } from 'lucide-react'
import { PageHeader } from './layout/PageHeader'
import { Button } from './ui/Button'
import { EmptyState } from './ui/EmptyState'
import { useApp } from '../context/AppContext'
import { ROLES, type Role } from '../lib/types'
import { paths } from '../routes/paths'

export function RoleGate({ allow, children }: { allow: Role[]; children: ReactNode }) {
  const { user } = useApp()
  const navigate = useNavigate()
  const [previewing, setPreviewing] = useState(false)

  if (allow.includes(user.role)) return <>{children}</>

  const allowedLabels = ROLES.filter((r) => allow.includes(r.id)).map((r) => r.shortLabel).join(' / ')
  const currentLabel = ROLES.find((r) => r.id === user.role)?.label

  if (previewing) {
    return (
      <div>
        <div className="sticky top-0 z-40 flex items-center gap-2 bg-gold-500 px-4 py-2 pt-[calc(env(safe-area-inset-top)+0.5rem)] text-white">
          <ShieldOff className="h-3.5 w-3.5 shrink-0" />
          <p className="flex-1 text-[11px] font-medium leading-tight">
            Previewing a {allowedLabels} screen as {currentLabel}
          </p>
          <Link to={paths.profileSettings} className="shrink-0 text-[11px] font-bold underline">Switch role</Link>
          <button onClick={() => setPreviewing(false)} className="shrink-0">
            <X className="h-4 w-4" />
          </button>
        </div>
        {children}
      </div>
    )
  }

  return (
    <div>
      <PageHeader title="Restricted" />
      <div className="px-4 pt-10">
        <EmptyState
          icon={<ShieldOff className="h-6 w-6" />}
          title="Not part of your role"
          description={`This section is built for ${allowedLabels}. You're currently viewing as ${currentLabel}.`}
          action={
            <div className="flex flex-wrap justify-center gap-2">
              <Button variant="outline" onClick={() => navigate(-1)}>Go Back</Button>
              <Button variant="secondary" icon={<Eye className="h-4 w-4" />} onClick={() => setPreviewing(true)}>
                Preview Anyway
              </Button>
              <Link to={paths.profileSettings}>
                <Button>Switch Role</Button>
              </Link>
            </div>
          }
        />
      </div>
    </div>
  )
}
