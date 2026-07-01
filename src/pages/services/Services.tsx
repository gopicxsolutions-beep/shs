import type { ReactNode } from 'react'
import {
  Wallet, Landmark, CalendarDays, BookOpen, Sprout, Store, FileText,
  GraduationCap, QrCode, Megaphone, LifeBuoy, Sparkles, FileBarChart,
  LineChart, Users, ShieldCog, ClipboardCheck, Building2, ServerCog,
} from 'lucide-react'
import { IconTile } from '../../components/ui/IconTile'
import { useApp } from '../../context/AppContext'
import { ROLES } from '../../lib/types'
import { paths } from '../../routes/paths'

function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div className="mt-6">
      <h2 className="px-4 text-xs font-bold uppercase tracking-wide text-ink-400">{title}</h2>
      <div className="mt-3 grid grid-cols-4 gap-y-5 px-4">{children}</div>
    </div>
  )
}

export function Services() {
  const { user } = useApp()
  const roleInfo = ROLES.find((r) => r.id === user.role)!

  return (
    <div>
      <div className="px-4 pb-3 pt-[calc(env(safe-area-inset-top)+1.25rem)]">
        <h1 className="font-display text-xl font-bold text-ink-900">Services</h1>
        <p className="text-xs text-ink-500 mt-0.5">Tailored for {roleInfo.label}</p>
      </div>

      {/* MEMBER */}
      {user.role === 'member' && (
        <>
          <Section title="Finance">
            <IconTile to={paths.savings} icon={<Wallet className="h-5.5 w-5.5" />} label="Savings" tone="brand" />
            <IconTile to={paths.loans} icon={<Landmark className="h-5.5 w-5.5" />} label="Loans" tone="gold" />
            <IconTile to={paths.payments} icon={<QrCode className="h-5.5 w-5.5" />} label="Digital Payments" tone="violet" />
          </Section>
          <Section title="My Group">
            <IconTile to={paths.meetings} icon={<CalendarDays className="h-5.5 w-5.5" />} label="Meetings" tone="brand" />
            <IconTile to={paths.livelihood} icon={<Sprout className="h-5.5 w-5.5" />} label="Livelihoods" tone="gold" />
            <IconTile to={paths.marketplace} icon={<Store className="h-5.5 w-5.5" />} label="Marketplace" tone="sky" />
            <IconTile to={paths.announcements} icon={<Megaphone className="h-5.5 w-5.5" />} label="Announcements" tone="rose" />
          </Section>
          <Section title="Growth">
            <IconTile to={paths.schemes} icon={<FileText className="h-5.5 w-5.5" />} label="Govt. Schemes" tone="brand" />
            <IconTile to={paths.training} icon={<GraduationCap className="h-5.5 w-5.5" />} label="Training" tone="gold" />
            <IconTile to={paths.aiHub} icon={<Sparkles className="h-5.5 w-5.5" />} label="AI Advisor" tone="violet" />
            <IconTile to={paths.reportsMember} icon={<FileBarChart className="h-5.5 w-5.5" />} label="My Reports" tone="sky" />
          </Section>
        </>
      )}

      {/* LEADER */}
      {user.role === 'leader' && (
        <>
          <Section title="Group Management">
            <IconTile to={paths.shgMembers} icon={<Users className="h-5.5 w-5.5" />} label="Members" tone="brand" />
            <IconTile to={paths.meetingSchedule} icon={<CalendarDays className="h-5.5 w-5.5" />} label="Schedule Meeting" tone="gold" />
            <IconTile to={paths.meetingAttendance} icon={<ClipboardCheck className="h-5.5 w-5.5" />} label="Mark Attendance" tone="sky" />
            <IconTile to={paths.loanApproval} icon={<ClipboardCheck className="h-5.5 w-5.5" />} label="Loan Approvals" tone="violet" />
          </Section>
          <Section title="Finance">
            <IconTile to={paths.savings} icon={<Wallet className="h-5.5 w-5.5" />} label="Savings" tone="brand" />
            <IconTile to={paths.loans} icon={<Landmark className="h-5.5 w-5.5" />} label="Loans" tone="gold" />
            <IconTile to={paths.financialCashbook} icon={<BookOpen className="h-5.5 w-5.5" />} label="Financial Records" tone="sky" />
            <IconTile to={paths.payments} icon={<QrCode className="h-5.5 w-5.5" />} label="Digital Payments" tone="violet" />
          </Section>
          <Section title="Group Activities">
            <IconTile to={paths.livelihood} icon={<Sprout className="h-5.5 w-5.5" />} label="Livelihoods" tone="brand" />
            <IconTile to={paths.marketplace} icon={<Store className="h-5.5 w-5.5" />} label="Marketplace" tone="gold" />
            <IconTile to={paths.announcements} icon={<Megaphone className="h-5.5 w-5.5" />} label="Announcements" tone="rose" />
            <IconTile to={paths.reportsShg} icon={<FileBarChart className="h-5.5 w-5.5" />} label="SHG Reports" tone="sky" />
          </Section>
          <Section title="Growth">
            <IconTile to={paths.schemes} icon={<FileText className="h-5.5 w-5.5" />} label="Govt. Schemes" tone="brand" />
            <IconTile to={paths.training} icon={<GraduationCap className="h-5.5 w-5.5" />} label="Training" tone="gold" />
            <IconTile to={paths.aiHub} icon={<Sparkles className="h-5.5 w-5.5" />} label="AI Advisor" tone="violet" />
          </Section>
        </>
      )}

      {/* CRP */}
      {user.role === 'crp' && (
        <>
          <Section title="Field Monitoring">
            <IconTile to={paths.analyticsShgList} icon={<Building2 className="h-5.5 w-5.5" />} label="Monitor SHGs" tone="brand" />
            <IconTile to={paths.analytics} icon={<LineChart className="h-5.5 w-5.5" />} label="Performance" tone="gold" />
            <IconTile to={paths.reportsFederation} icon={<FileBarChart className="h-5.5 w-5.5" />} label="Cluster Reports" tone="sky" />
          </Section>
          <Section title="Capacity Building">
            <IconTile to={paths.training} icon={<GraduationCap className="h-5.5 w-5.5" />} label="Training Updates" tone="brand" />
            <IconTile to={paths.schemes} icon={<FileText className="h-5.5 w-5.5" />} label="Govt. Schemes" tone="gold" />
            <IconTile to={paths.aiHub} icon={<Sparkles className="h-5.5 w-5.5" />} label="AI Advisor" tone="violet" />
            <IconTile to={paths.announcements} icon={<Megaphone className="h-5.5 w-5.5" />} label="Announcements" tone="rose" />
          </Section>
        </>
      )}

      {/* CLF */}
      {user.role === 'clf' && (
        <>
          <Section title="Federation Oversight">
            <IconTile to={paths.analyticsShgList} icon={<Building2 className="h-5.5 w-5.5" />} label="Village Orgs" tone="brand" />
            <IconTile to={paths.analytics} icon={<LineChart className="h-5.5 w-5.5" />} label="Analytics" tone="gold" />
            <IconTile to={paths.reportsFederation} icon={<FileBarChart className="h-5.5 w-5.5" />} label="Federation Reports" tone="sky" />
          </Section>
          <Section title="Reference">
            <IconTile to={paths.schemes} icon={<FileText className="h-5.5 w-5.5" />} label="Govt. Schemes" tone="brand" />
            <IconTile to={paths.training} icon={<GraduationCap className="h-5.5 w-5.5" />} label="Training" tone="gold" />
            <IconTile to={paths.announcements} icon={<Megaphone className="h-5.5 w-5.5" />} label="Announcements" tone="rose" />
          </Section>
        </>
      )}

      {/* ADMIN */}
      {user.role === 'admin' && (
        <>
          <Section title="Administration">
            <IconTile to={paths.adminUsers} icon={<Users className="h-5.5 w-5.5" />} label="User Management" tone="brand" />
            <IconTile to={paths.adminSchemes} icon={<ShieldCog className="h-5.5 w-5.5" />} label="Scheme Management" tone="gold" />
            <IconTile to={paths.adminMonitoring} icon={<ServerCog className="h-5.5 w-5.5" />} label="System Monitoring" tone="sky" />
          </Section>
          <Section title="Oversight & Reports">
            <IconTile to={paths.analytics} icon={<LineChart className="h-5.5 w-5.5" />} label="Analytics" tone="brand" />
            <IconTile to={paths.analyticsShgList} icon={<Building2 className="h-5.5 w-5.5" />} label="All SHGs" tone="gold" />
            <IconTile to={paths.reportsFederation} icon={<FileBarChart className="h-5.5 w-5.5" />} label="Federation Reports" tone="sky" />
            <IconTile to={paths.announcements} icon={<Megaphone className="h-5.5 w-5.5" />} label="Announcements" tone="rose" />
          </Section>
        </>
      )}

      <Section title="Support">
        <IconTile to={paths.support} icon={<LifeBuoy className="h-5.5 w-5.5" />} label="Help & Support" tone="rose" />
      </Section>

      <div className="h-6" />
    </div>
  )
}
