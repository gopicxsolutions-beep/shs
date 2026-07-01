import {
  Wallet, Landmark, CalendarDays, BookOpen, Sprout, Store, FileText,
  GraduationCap, QrCode, Megaphone, LifeBuoy, Sparkles, FileBarChart,
  LineChart, Users, ShieldCog,
} from 'lucide-react'
import { IconTile } from '../../components/ui/IconTile'
import { useApp } from '../../context/AppContext'
import { paths } from '../../routes/paths'

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="mt-6">
      <h2 className="px-4 text-xs font-bold uppercase tracking-wide text-ink-400">{title}</h2>
      <div className="mt-3 grid grid-cols-4 gap-y-5 px-4">{children}</div>
    </div>
  )
}

export function Services() {
  const { user } = useApp()

  return (
    <div>
      <div className="px-4 pb-3 pt-[calc(env(safe-area-inset-top)+1.25rem)]">
        <h1 className="font-display text-xl font-bold text-ink-900">Services</h1>
        <p className="text-xs text-ink-500 mt-0.5">Everything your SHG needs, in one place</p>
      </div>

      <Section title="Finance">
        <IconTile to={paths.savings} icon={<Wallet className="h-5.5 w-5.5" />} label="Savings" tone="brand" />
        <IconTile to={paths.loans} icon={<Landmark className="h-5.5 w-5.5" />} label="Loans" tone="gold" />
        <IconTile to={paths.financialCashbook} icon={<BookOpen className="h-5.5 w-5.5" />} label="Financial Records" tone="sky" />
        <IconTile to={paths.payments} icon={<QrCode className="h-5.5 w-5.5" />} label="Digital Payments" tone="violet" />
      </Section>

      <Section title="Group Activities">
        <IconTile to={paths.meetings} icon={<CalendarDays className="h-5.5 w-5.5" />} label="Meetings" tone="brand" />
        <IconTile to={paths.livelihood} icon={<Sprout className="h-5.5 w-5.5" />} label="Livelihoods" tone="gold" />
        <IconTile to={paths.marketplace} icon={<Store className="h-5.5 w-5.5" />} label="Marketplace" tone="sky" />
        <IconTile to={paths.announcements} icon={<Megaphone className="h-5.5 w-5.5" />} label="Announcements" tone="rose" />
      </Section>

      <Section title="Growth">
        <IconTile to={paths.schemes} icon={<FileText className="h-5.5 w-5.5" />} label="Govt. Schemes" tone="brand" />
        <IconTile to={paths.training} icon={<GraduationCap className="h-5.5 w-5.5" />} label="Training" tone="gold" />
        <IconTile to={paths.aiHub} icon={<Sparkles className="h-5.5 w-5.5" />} label="AI Advisor" tone="violet" />
        <IconTile to={paths.reports} icon={<FileBarChart className="h-5.5 w-5.5" />} label="Reports" tone="sky" />
      </Section>

      {(user.role === 'crp' || user.role === 'clf' || user.role === 'admin') && (
        <Section title="Oversight">
          <IconTile to={paths.analytics} icon={<LineChart className="h-5.5 w-5.5" />} label="Analytics" tone="brand" />
          {user.role === 'admin' && (
            <>
              <IconTile to={paths.adminUsers} icon={<Users className="h-5.5 w-5.5" />} label="Users" tone="gold" />
              <IconTile to={paths.adminSchemes} icon={<ShieldCog className="h-5.5 w-5.5" />} label="Admin Schemes" tone="sky" />
            </>
          )}
        </Section>
      )}

      <Section title="Support">
        <IconTile to={paths.support} icon={<LifeBuoy className="h-5.5 w-5.5" />} label="Help & Support" tone="rose" />
      </Section>

      <div className="h-6" />
    </div>
  )
}
