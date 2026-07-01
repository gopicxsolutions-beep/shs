import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { CheckCircle2, UploadCloud, IndianRupee } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
import { Input, Textarea } from '../../components/ui/Field'
import { useApp } from '../../context/AppContext'
import { useData } from '../../context/DataContext'
import { paths } from '../../routes/paths'

export function LoanApply() {
  const navigate = useNavigate()
  const { user } = useApp()
  const { addLoanRequest } = useData()
  const [amount, setAmount] = useState('20000')
  const [purpose, setPurpose] = useState('')
  const [tenureMonths, setTenureMonths] = useState('12')
  const [submitted, setSubmitted] = useState(false)

  if (submitted) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center px-8 text-center">
        <div className="flex h-16 w-16 items-center justify-center rounded-full bg-brand-50 text-brand-600">
          <CheckCircle2 className="h-9 w-9" />
        </div>
        <h1 className="mt-5 font-display text-xl font-bold text-ink-900">Application submitted!</h1>
        <p className="mt-1.5 text-sm text-ink-500">
          Your request for ₹{amount} has been sent to your SHG leader for approval.
        </p>
        <Button className="mt-8" fullWidth size="lg" onClick={() => navigate(paths.loans)}>
          Back to Loans
        </Button>
      </div>
    )
  }

  return (
    <div className="pb-6">
      <PageHeader title="Apply for Loan" />
      <form
        className="px-4 mt-2 space-y-4"
        onSubmit={(e) => {
          e.preventDefault()
          addLoanRequest({
            memberName: user.name,
            purpose: purpose || 'General purpose loan',
            amount: Number(amount),
            tenureMonths: Number(tenureMonths),
          })
          setSubmitted(true)
        }}
      >
        <Input
          label="Loan amount requested"
          type="number"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          icon={<IndianRupee className="h-4 w-4" />}
          required
        />
        <Textarea
          label="Purpose of loan"
          placeholder="e.g. Purchase of milch cow for dairy"
          rows={3}
          value={purpose}
          onChange={(e) => setPurpose(e.target.value)}
          required
        />
        <div className="grid grid-cols-2 gap-3">
          <Input
            label="Tenure (months)"
            type="number"
            value={tenureMonths}
            onChange={(e) => setTenureMonths(e.target.value)}
            required
          />
          <Input label="Preferred EMI" type="number" placeholder="Auto-calculated" disabled />
        </div>

        <div>
          <label className="mb-1.5 block text-xs font-semibold text-ink-600">Upload supporting document</label>
          <Card className="flex flex-col items-center justify-center gap-2 border-dashed !py-8 text-ink-400">
            <UploadCloud className="h-7 w-7" />
            <span className="text-xs">Tap to upload quotation / proof</span>
          </Card>
        </div>

        <Button type="submit" fullWidth size="lg" className="mt-2">
          Submit Application
        </Button>
      </form>
    </div>
  )
}
