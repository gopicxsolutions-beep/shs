export interface Activity {
  id: string
  category: 'Agriculture' | 'Dairy' | 'Poultry' | 'Tailoring' | 'Handicrafts' | 'Food Processing'
  member: string
  production: string
  income: number
  expense: number
  month: string
}

export const activities: Activity[] = [
  { id: 'a1', category: 'Dairy', member: 'Lakshmi Devi', production: '180 L milk', income: 9200, expense: 3400, month: 'Jun 2026' },
  { id: 'a2', category: 'Tailoring', member: 'Rajeshwari', production: '42 garments', income: 8600, expense: 2200, month: 'Jun 2026' },
  { id: 'a3', category: 'Poultry', member: 'Durga Bhavani', production: '640 eggs', income: 4800, expense: 1900, month: 'Jun 2026' },
  { id: 'a4', category: 'Agriculture', member: 'Gowramma', production: '3.2 quintal vegetables', income: 11200, expense: 4600, month: 'Jun 2026' },
  { id: 'a5', category: 'Handicrafts', member: 'Jyothi', production: '25 bamboo baskets', income: 5200, expense: 1400, month: 'Jun 2026' },
  { id: 'a6', category: 'Food Processing', member: 'Anasuya', production: '60 kg pickles', income: 7800, expense: 2900, month: 'Jun 2026' },
]

export const categoryMeta: Record<Activity['category'], { icon: string; color: string }> = {
  Agriculture: { icon: '🌾', color: 'bg-brand-50 text-brand-700' },
  Dairy: { icon: '🐄', color: 'bg-sky-50 text-sky-700' },
  Poultry: { icon: '🐔', color: 'bg-gold-50 text-gold-700' },
  Tailoring: { icon: '🧵', color: 'bg-rose-50 text-rose-700' },
  Handicrafts: { icon: '🧺', color: 'bg-violet-50 text-violet-700' },
  'Food Processing': { icon: '🥫', color: 'bg-ink-100 text-ink-700' },
}
