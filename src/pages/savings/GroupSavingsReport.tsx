import { BarChart, Bar, ResponsiveContainer, XAxis } from 'recharts'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Avatar } from '../../components/ui/Avatar'
import { ProgressBar } from '../../components/ui/ProgressBar'
import { members } from '../../data/members'

export function GroupSavingsReport() {
  const total = members.reduce((s, m) => s + m.savings, 0)
  const top = members.slice().sort((a, b) => b.savings - a.savings)
  const chartData = top.slice(0, 6).map((m) => ({ name: m.name.split(' ')[0], savings: m.savings }))

  return (
    <div className="pb-6">
      <PageHeader title="Group Savings Report" subtitle={`Total ₹${total.toLocaleString('en-IN')}`} />
      <div className="px-4 mt-2">
        <Card>
          <div className="h-40">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={chartData}>
                <XAxis dataKey="name" tick={{ fontSize: 9, fill: '#647873' }} axisLine={false} tickLine={false} />
                <Bar dataKey="savings" fill="#0e8a66" radius={[6, 6, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </Card>
      </div>

      <div className="px-4 mt-5">
        <h2 className="text-[15px] font-bold text-ink-900 font-display mb-3">Member-wise Savings</h2>
        <div className="space-y-3">
          {top.map((m) => (
            <Card key={m.id} className="!p-3.5 flex items-center gap-3">
              <Avatar name={m.name} size="sm" />
              <div className="min-w-0 flex-1">
                <div className="flex items-center justify-between">
                  <p className="text-xs font-semibold text-ink-800 truncate">{m.name}</p>
                  <p className="text-xs font-bold text-brand-700">₹{m.savings.toLocaleString('en-IN')}</p>
                </div>
                <ProgressBar value={m.savings} max={top[0].savings} className="mt-1.5" />
              </div>
            </Card>
          ))}
        </div>
      </div>
    </div>
  )
}
