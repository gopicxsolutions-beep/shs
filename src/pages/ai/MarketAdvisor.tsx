import { AreaChart, Area, BarChart, Bar, ResponsiveContainer, XAxis } from 'recharts'
import { Sparkles, TrendingUp, Leaf, ShoppingBasket } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Badge } from '../../components/ui/Badge'
import { SectionHeader } from '../../components/ui/SectionHeader'

const demandForecast = [
  { month: 'Feb', value: 40 },
  { month: 'Mar', value: 48 },
  { month: 'Apr', value: 52 },
  { month: 'May', value: 58 },
  { month: 'Jun', value: 68 },
  { month: 'Jul', value: 74 },
]

const priceTrend = [
  { month: 'Feb', price: 210 },
  { month: 'Mar', price: 224 },
  { month: 'Apr', price: 232 },
  { month: 'May', price: 241 },
  { month: 'Jun', price: 256 },
  { month: 'Jul', price: 262 },
]

const opportunities = [
  {
    icon: Leaf,
    title: 'Turmeric powder demand up 22% this season',
    detail: 'Festive-season demand is rising in nearby markets. Consider increasing production for the next 6 weeks.',
  },
  {
    icon: ShoppingBasket,
    title: 'Handloom sarees trending in Warangal market',
    detail: 'Local retailers are reporting a 15% rise in enquiries. Good opportunity for bulk orders.',
  },
  {
    icon: TrendingUp,
    title: 'Millet-based snacks gaining traction online',
    detail: 'Health-food demand is growing — consider listing on the SHG marketplace with festival packaging.',
  },
]

export function MarketAdvisor() {
  return (
    <div className="pb-6">
      <PageHeader title="Market Advisor" subtitle="AI demand & pricing insights for your products" />

      <div className="px-4 mt-2">
        <Card className="flex items-center gap-2 bg-violet-50 border-violet-100">
          <Sparkles className="h-4 w-4 text-violet-600 shrink-0" />
          <p className="text-[11px] text-violet-700 leading-relaxed">
            Forecasts are generated from regional sales trends and seasonal demand patterns.
          </p>
        </Card>
      </div>

      <div className="px-4 mt-5">
        <SectionHeader title="Product Demand Forecast" subtitle="Turmeric powder · units/week (indicative)" />
        <Card>
          <div className="h-40">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={demandForecast}>
                <XAxis dataKey="month" tick={{ fontSize: 9, fill: '#647873' }} axisLine={false} tickLine={false} />
                <Bar dataKey="value" fill="#7c3aed" radius={[6, 6, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </Card>
      </div>

      <div className="px-4 mt-5">
        <SectionHeader title="Price Trend" subtitle="₹ per kg · last 6 months" />
        <Card>
          <div className="h-40">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={priceTrend}>
                <defs>
                  <linearGradient id="priceTrendGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="#7c3aed" stopOpacity={0.4} />
                    <stop offset="100%" stopColor="#7c3aed" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <XAxis dataKey="month" tick={{ fontSize: 9, fill: '#647873' }} axisLine={false} tickLine={false} />
                <Area type="monotone" dataKey="price" stroke="#7c3aed" strokeWidth={2} fill="url(#priceTrendGradient)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </Card>
      </div>

      <div className="px-4 mt-6">
        <div className="flex items-center justify-between mb-2">
          <p className="text-[15px] font-bold text-ink-900 font-display">Market Opportunities</p>
          <Badge tone="brand" className="!bg-violet-50 !text-violet-700">✨ AI Insight</Badge>
        </div>
        <div className="space-y-3">
          {opportunities.map((o) => {
            const Icon = o.icon
            return (
              <Card key={o.title} className="flex items-start gap-3">
                <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-violet-50 text-violet-600">
                  <Icon className="h-5 w-5" />
                </div>
                <div className="min-w-0">
                  <p className="text-sm font-semibold text-ink-900">{o.title}</p>
                  <p className="text-xs text-ink-500 mt-1 leading-relaxed">{o.detail}</p>
                </div>
              </Card>
            )
          })}
        </div>
      </div>
    </div>
  )
}
