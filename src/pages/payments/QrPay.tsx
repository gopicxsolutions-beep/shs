import { useState } from 'react'
import { QrCode, CheckCircle2, ScanLine, IndianRupee } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Button } from '../../components/ui/Button'
import { Input } from '../../components/ui/Field'
import { SegmentedTabs } from '../../components/ui/SegmentedTabs'

export function QrPay() {
  const [mode, setMode] = useState('show')
  const [amount, setAmount] = useState('500')
  const [done, setDone] = useState(false)

  return (
    <div className="pb-6">
      <PageHeader title="Scan & Pay" />

      <div className="px-4 mt-2">
        <SegmentedTabs
          options={[
            { value: 'show', label: 'Show to collect' },
            { value: 'scan', label: 'Scan to pay' },
          ]}
          value={mode}
          onChange={(v) => {
            setMode(v)
            setDone(false)
          }}
        />
      </div>

      <div className="px-6 mt-2 flex flex-col items-center text-center">
        {mode === 'show' && (
          <div className="w-full mt-6">
            <Input
              label="Amount to collect"
              type="number"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              icon={<IndianRupee className="h-4 w-4" />}
            />
          </div>
        )}

        <p className="text-sm font-semibold text-ink-800 mt-6">
          {mode === 'show' ? `Show this QR to collect ₹${amount}` : 'Scan to pay'}
        </p>
        <p className="text-xs text-ink-500 mt-0.5">
          {mode === 'show' ? 'Ask the member to scan using any UPI app' : 'Point your camera at the merchant / member QR code'}
        </p>

        <div className="relative mt-8 flex h-64 w-64 items-center justify-center rounded-3xl border-2 border-dashed border-brand-300 bg-brand-50/40">
          {done ? (
            <div className="flex flex-col items-center gap-2 text-brand-600">
              <CheckCircle2 className="h-16 w-16" />
              <p className="text-sm font-bold">{mode === 'show' ? 'Payment received!' : 'Payment sent!'}</p>
            </div>
          ) : (
            <>
              <QrCode className="h-28 w-28 text-brand-300" />
              {mode === 'scan' && <ScanLine className="absolute h-64 w-full animate-pulse text-brand-500/60" />}
            </>
          )}
        </div>

        <p className="mt-6 text-xs text-ink-500 max-w-[240px]">
          {done
            ? `₹${amount} ${mode === 'show' ? 'credited to SHG account' : 'debited via UPI'} successfully.`
            : mode === 'show'
              ? 'Your QR code refreshes automatically for security'
              : 'Camera preview mock — tap below to simulate a scan'}
        </p>

        {!done && (
          <Button className="mt-8" size="lg" onClick={() => setDone(true)}>
            {mode === 'show' ? 'Simulate Collection' : 'Simulate Scan'}
          </Button>
        )}
      </div>
    </div>
  )
}
