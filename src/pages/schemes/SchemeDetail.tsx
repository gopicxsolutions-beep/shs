import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { CheckCircle2, Building2, UploadCloud, FileCheck2 } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Badge } from '../../components/ui/Badge'
import { Button } from '../../components/ui/Button'
import { EmptyState } from '../../components/ui/EmptyState'
import { paths } from '../../routes/paths'
import { useData } from '../../context/DataContext'

const requiredDocuments = ['Aadhaar Card', 'Bank Passbook', 'SHG Membership Certificate', 'Income Certificate']

type Status = 'not_applied' | 'applied' | 'under_review' | 'approved' | 'rejected'

const statusTone: Record<Status, 'success' | 'warning' | 'info' | 'danger' | 'neutral'> = {
  approved: 'success',
  under_review: 'warning',
  applied: 'info',
  rejected: 'danger',
  not_applied: 'neutral',
}

const statusLabel: Record<Status, string> = {
  approved: 'Approved',
  under_review: 'Under Review',
  applied: 'Applied',
  rejected: 'Rejected',
  not_applied: 'Not Applied',
}

export function SchemeDetail() {
  const { id } = useParams()
  const { schemes, applyScheme } = useData()
  const scheme = schemes.find((s) => s.id === id)

  if (!scheme) {
    return (
      <div>
        <PageHeader title="Scheme" />
        <div className="px-4 pt-8">
          <EmptyState title="Scheme not found" description="This scheme may have been removed or is unavailable." />
        </div>
      </div>
    )
  }

  const [showUpload, setShowUpload] = useState(false)
  const [uploaded, setUploaded] = useState<Record<string, boolean>>({})
  const [justApplied, setJustApplied] = useState(false)
  const status = justApplied ? 'applied' : ((scheme.status ?? 'not_applied') as Status)
  const hasApplied = status !== 'not_applied'
  const allUploaded = requiredDocuments.every((d) => uploaded[d])

  if (justApplied) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center px-8 text-center">
        <div className="flex h-16 w-16 items-center justify-center rounded-full bg-brand-50 text-brand-600">
          <CheckCircle2 className="h-9 w-9" />
        </div>
        <h1 className="mt-5 font-display text-xl font-bold text-ink-900">Application submitted!</h1>
        <p className="mt-1.5 text-sm text-ink-500">
          Your application for {scheme.name} has been sent to your CRP for verification.
        </p>
        <Link to={paths.schemeTracking} className="mt-8 w-full">
          <Button fullWidth size="lg">Track Application</Button>
        </Link>
      </div>
    )
  }

  return (
    <div className="pb-6">
      <PageHeader title={scheme.name} subtitle={scheme.agency} />

      <div className="px-4 mt-2">
        <Card>
          <div className="flex items-start justify-between gap-2">
            <div className="min-w-0">
              <Badge tone="brand">{scheme.name}</Badge>
              <p className="text-base font-bold font-display text-ink-900 mt-2">{scheme.fullName}</p>
            </div>
            <Badge tone={statusTone[status]} className="shrink-0">{statusLabel[status]}</Badge>
          </div>
          <div className="flex items-center gap-1.5 mt-3 text-ink-500">
            <Building2 className="h-3.5 w-3.5" />
            <span className="text-xs">{scheme.agency}</span>
          </div>
          {scheme.deadline && (
            <p className="text-[11px] text-gold-700 mt-2 font-semibold">Deadline: {scheme.deadline}</p>
          )}
        </Card>
      </div>

      <div className="px-4 mt-5">
        <h2 className="text-[15px] font-bold text-ink-900 font-display mb-3">Benefit</h2>
        <Card className="bg-brand-50/40 border-brand-100">
          <p className="text-sm text-ink-800">{scheme.benefit}</p>
        </Card>
      </div>

      <div className="px-4 mt-5">
        <h2 className="text-[15px] font-bold text-ink-900 font-display mb-3">Eligibility Criteria</h2>
        <Card className="!p-0 divide-y divide-ink-100">
          {scheme.eligibility.map((e, i) => (
            <div key={i} className="flex items-start gap-2.5 px-4 py-3">
              <CheckCircle2 className="h-4 w-4 shrink-0 text-brand-600 mt-0.5" />
              <span className="text-xs text-ink-700">{e}</span>
            </div>
          ))}
        </Card>
      </div>

      {showUpload && !hasApplied && (
        <div className="px-4 mt-5">
          <h2 className="text-[15px] font-bold text-ink-900 font-display mb-3">Document Upload</h2>
          <Card className="!p-0 divide-y divide-ink-100">
            {requiredDocuments.map((doc) => (
              <button
                key={doc}
                onClick={() => setUploaded((u) => ({ ...u, [doc]: !u[doc] }))}
                className="flex w-full items-center gap-3 px-4 py-3 text-left"
              >
                <div
                  className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-lg ${uploaded[doc] ? 'bg-brand-50 text-brand-600' : 'bg-ink-100 text-ink-400'}`}
                >
                  {uploaded[doc] ? <FileCheck2 className="h-4 w-4" /> : <UploadCloud className="h-4 w-4" />}
                </div>
                <span className="flex-1 text-xs font-semibold text-ink-800">{doc}</span>
                <Badge tone={uploaded[doc] ? 'success' : 'neutral'}>{uploaded[doc] ? 'Uploaded' : 'Tap to upload'}</Badge>
              </button>
            ))}
          </Card>
        </div>
      )}

      <div className="px-4 mt-6">
        {hasApplied ? (
          <Link to={paths.schemeTracking}>
            <Button fullWidth size="lg" variant="secondary">View Application Status</Button>
          </Link>
        ) : showUpload ? (
          <Button
            fullWidth
            size="lg"
            disabled={!allUploaded}
            onClick={() => {
              applyScheme(scheme.id)
              setJustApplied(true)
            }}
          >
            Submit Application
          </Button>
        ) : (
          <Button fullWidth size="lg" onClick={() => setShowUpload(true)}>Apply Now</Button>
        )}
      </div>
    </div>
  )
}
