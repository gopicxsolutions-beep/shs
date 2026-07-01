export interface SavingsEntry {
  id: string
  memberName: string
  date: string
  amount: number
  mode: 'Cash' | 'UPI' | 'Bank Transfer'
  type: 'Weekly' | 'Monthly' | 'Daily'
  status: 'verified' | 'pending'
}

export const savingsEntries: SavingsEntry[] = [
  { id: 's1', memberName: 'Lakshmi Devi', date: '28 Jun 2026', amount: 500, mode: 'UPI', type: 'Weekly', status: 'verified' },
  { id: 's2', memberName: 'Padma Reddy', date: '28 Jun 2026', amount: 500, mode: 'Cash', type: 'Weekly', status: 'verified' },
  { id: 's3', memberName: 'Rajeshwari', date: '28 Jun 2026', amount: 300, mode: 'Cash', type: 'Weekly', status: 'verified' },
  { id: 's4', memberName: 'Anasuya', date: '28 Jun 2026', amount: 500, mode: 'UPI', type: 'Weekly', status: 'pending' },
  { id: 's5', memberName: 'Bhavani', date: '21 Jun 2026', amount: 500, mode: 'Cash', type: 'Weekly', status: 'verified' },
  { id: 's6', memberName: 'Chandrakala', date: '21 Jun 2026', amount: 400, mode: 'Bank Transfer', type: 'Weekly', status: 'verified' },
  { id: 's7', memberName: 'Durga Bhavani', date: '21 Jun 2026', amount: 300, mode: 'Cash', type: 'Weekly', status: 'verified' },
  { id: 's8', memberName: 'Eswari', date: '14 Jun 2026', amount: 500, mode: 'UPI', type: 'Weekly', status: 'verified' },
]

export const savingsMonthlyTrend = [
  { month: 'Jan', amount: 32000 },
  { month: 'Feb', amount: 35500 },
  { month: 'Mar', amount: 34000 },
  { month: 'Apr', amount: 38200 },
  { month: 'May', amount: 41000 },
  { month: 'Jun', amount: 44500 },
]
