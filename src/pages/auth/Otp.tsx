import { useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { MessageSquareLock } from 'lucide-react'
import { Button } from '../../components/ui/Button'
import { paths } from '../../routes/paths'

export function Otp() {
  const navigate = useNavigate()
  const [digits, setDigits] = useState(Array(6).fill(''))
  const refs = useRef<(HTMLInputElement | null)[]>([])
  const filled = digits.every((d) => d !== '')

  function update(i: number, val: string) {
    const v = val.replace(/\D/g, '').slice(-1)
    const next = [...digits]
    next[i] = v
    setDigits(next)
    if (v && i < 5) refs.current[i + 1]?.focus()
  }

  return (
    <div className="flex min-h-screen flex-col justify-between bg-ink-50 px-6 pb-8 pt-16">
      <div>
        <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-3xl bg-brand-600 shadow-lg shadow-brand-600/30">
          <MessageSquareLock className="h-7 w-7 text-white" />
        </div>
        <h1 className="mt-6 text-center font-display text-2xl font-bold text-ink-900">Verify OTP</h1>
        <p className="mt-1.5 text-center text-sm text-ink-500">
          We've sent a 6-digit code to <span className="font-semibold text-ink-700">+91 98765 43210</span>
        </p>

        <div className="mt-8 flex justify-between gap-2">
          {digits.map((d, i) => (
            <input
              key={i}
              ref={(el) => {
                refs.current[i] = el
              }}
              value={d}
              onChange={(e) => update(i, e.target.value)}
              inputMode="numeric"
              maxLength={1}
              className="h-13 w-11 rounded-xl border border-ink-200 bg-white text-center text-lg font-bold text-ink-900 outline-none focus:border-brand-500 focus:ring-2 focus:ring-brand-100"
            />
          ))}
        </div>

        <button className="mt-5 w-full text-center text-xs font-semibold text-brand-600">
          Resend OTP in <span className="text-ink-400 font-normal">00:28</span>
        </button>

        <Button
          fullWidth
          size="lg"
          className="mt-8"
          disabled={!filled}
          onClick={() => navigate(paths.profileSetup)}
        >
          Verify &amp; Continue
        </Button>
      </div>

      <p className="text-center text-[11px] text-ink-400">Didn't receive the code? Check your SMS inbox.</p>
    </div>
  )
}
