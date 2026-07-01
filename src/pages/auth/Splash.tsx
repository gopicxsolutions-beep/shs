import { useNavigate } from 'react-router-dom'
import { Sprout, ShieldCheck, TrendingUp, Users2 } from 'lucide-react'
import { paths } from '../../routes/paths'

export function Splash() {
  const navigate = useNavigate()
  return (
    <div className="flex min-h-screen flex-col justify-between bg-[radial-gradient(circle_at_50%_-10%,#18ab7c_0%,#0d6f55_45%,#042e24_100%)] px-6 pb-10 pt-16 text-white">
      <div>
        <div className="flex items-center gap-2">
          <div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-white/15 backdrop-blur">
            <Sprout className="h-6 w-6" />
          </div>
          <span className="text-sm font-semibold tracking-wide text-white/80">SHG SAATHI</span>
        </div>

        <div className="mt-14 animate-fade-up">
          <h1 className="font-display text-[34px] font-bold leading-[1.15] text-balance">
            Empowering Self-Help Groups, together.
          </h1>
          <p className="mt-3 max-w-xs text-sm text-white/75">
            Savings, loans, meetings, schemes, marketplace &amp; more — everything your SHG needs, in one app.
          </p>
        </div>

        <div className="mt-10 grid grid-cols-2 gap-3">
          {[
            { icon: TrendingUp, label: 'Savings & Loans' },
            { icon: Users2, label: 'Group Management' },
            { icon: ShieldCheck, label: 'Govt. Schemes' },
            { icon: Sprout, label: 'Livelihoods' },
          ].map(({ icon: Icon, label }) => (
            <div key={label} className="flex items-center gap-2 rounded-xl bg-white/10 px-3 py-2.5 backdrop-blur">
              <Icon className="h-4 w-4 shrink-0 text-gold-300" />
              <span className="text-xs font-medium text-white/90">{label}</span>
            </div>
          ))}
        </div>
      </div>

      <div className="animate-fade-up">
        <button
          onClick={() => navigate(paths.login)}
          className="flex w-full items-center justify-center rounded-2xl bg-white py-3.5 text-sm font-bold text-brand-700 shadow-xl active:scale-[0.98] transition"
        >
          Get Started
        </button>
        <p className="mt-4 text-center text-[11px] text-white/60">
          Available in English · తెలుగు · हिंदी
        </p>
      </div>
    </div>
  )
}
