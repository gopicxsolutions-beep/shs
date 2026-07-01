import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Phone, ShieldCheck } from 'lucide-react'
import { Button } from '../../components/ui/Button'
import { Input } from '../../components/ui/Field'
import { paths } from '../../routes/paths'

export function Login() {
  const navigate = useNavigate()
  const [mobile, setMobile] = useState('')

  return (
    <div className="flex min-h-screen flex-col justify-between bg-ink-50 px-6 pb-8 pt-16">
      <div>
        <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-3xl bg-brand-600 shadow-lg shadow-brand-600/30">
          <Phone className="h-7 w-7 text-white" />
        </div>
        <h1 className="mt-6 text-center font-display text-2xl font-bold text-ink-900">Welcome back</h1>
        <p className="mt-1.5 text-center text-sm text-ink-500">
          Enter your registered mobile number to continue
        </p>

        <form
          className="mt-8 space-y-4"
          onSubmit={(e) => {
            e.preventDefault()
            navigate(paths.otp)
          }}
        >
          <Input
            label="Mobile number"
            type="tel"
            inputMode="numeric"
            maxLength={10}
            placeholder="98765 43210"
            value={mobile}
            onChange={(e) => setMobile(e.target.value.replace(/\D/g, ''))}
            icon={<span className="text-sm font-semibold text-ink-500">+91</span>}
            required
          />
          <Button type="submit" fullWidth size="lg" disabled={mobile.length < 10}>
            Send OTP
          </Button>
        </form>

        <div className="mt-6 flex items-center gap-2 rounded-xl bg-brand-50 p-3">
          <ShieldCheck className="h-4 w-4 shrink-0 text-brand-600" />
          <p className="text-[11px] leading-snug text-brand-700">
            Your data is protected under DAY-NRLM guidelines. We never share your Aadhaar details.
          </p>
        </div>
      </div>

      <p className="text-center text-[11px] text-ink-400">
        By continuing you agree to the Terms of Service &amp; Privacy Policy
      </p>
    </div>
  )
}
