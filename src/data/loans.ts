export interface Loan {
  id: string
  memberName: string
  purpose: string
  amount: number
  outstanding: number
  emi: number
  tenureMonths: number
  disbursedOn: string
  status: 'pending' | 'approved' | 'rejected' | 'active' | 'closed' | 'overdue'
  nextDueDate?: string
}

export const loans: Loan[] = [
  { id: 'l1', memberName: 'Lakshmi Devi', purpose: 'Dairy — buy milch cow', amount: 30000, outstanding: 22000, emi: 2500, tenureMonths: 12, disbursedOn: '10 Jan 2026', status: 'active', nextDueDate: '10 Jul 2026' },
  { id: 'l2', memberName: 'Rajeshwari', purpose: 'Tailoring machine purchase', amount: 25000, outstanding: 18500, emi: 2100, tenureMonths: 12, disbursedOn: '05 Feb 2026', status: 'active', nextDueDate: '05 Jul 2026' },
  { id: 'l3', memberName: 'Bhavani', purpose: 'Kirana shop working capital', amount: 15000, outstanding: 12000, emi: 1300, tenureMonths: 12, disbursedOn: '20 Mar 2026', status: 'active', nextDueDate: '20 Jul 2026' },
  { id: 'l4', memberName: 'Durga Bhavani', purpose: 'Poultry farming', amount: 12000, outstanding: 9000, emi: 1000, tenureMonths: 12, disbursedOn: '15 Apr 2026', status: 'overdue', nextDueDate: '15 Jun 2026' },
  { id: 'l5', memberName: 'Gowramma', purpose: 'Agriculture inputs — seeds & fertiliser', amount: 20000, outstanding: 15500, emi: 1700, tenureMonths: 12, disbursedOn: '02 May 2026', status: 'active', nextDueDate: '02 Jul 2026' },
  { id: 'l6', memberName: 'Jyothi', purpose: 'Handicraft raw material', amount: 10000, outstanding: 8000, emi: 900, tenureMonths: 12, disbursedOn: '18 May 2026', status: 'active', nextDueDate: '18 Jul 2026' },
  { id: 'l7', memberName: 'Anasuya', purpose: 'Food processing unit expansion', amount: 35000, outstanding: 35000, emi: 0, tenureMonths: 18, disbursedOn: '', status: 'pending' },
  { id: 'l8', memberName: 'Hemalatha', purpose: 'Vegetable vending cart', amount: 8000, outstanding: 8000, emi: 0, tenureMonths: 10, disbursedOn: '', status: 'pending' },
]

export const loanTrend = [
  { month: 'Jan', disbursed: 30000, recovered: 8000 },
  { month: 'Feb', disbursed: 25000, recovered: 12000 },
  { month: 'Mar', disbursed: 15000, recovered: 15500 },
  { month: 'Apr', disbursed: 12000, recovered: 17200 },
  { month: 'May', disbursed: 30000, recovered: 19800 },
  { month: 'Jun', disbursed: 0, recovered: 21400 },
]
