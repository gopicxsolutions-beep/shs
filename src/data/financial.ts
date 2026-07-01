export interface CashEntry {
  id: string
  date: string
  particulars: string
  type: 'receipt' | 'payment'
  amount: number
  balance: number
}

export const cashBook: CashEntry[] = [
  { id: 'c1', date: '28 Jun 2026', particulars: 'Weekly savings collection', type: 'receipt', amount: 4600, balance: 68400 },
  { id: 'c2', date: '27 Jun 2026', particulars: 'Loan repayment — Rajeshwari', type: 'receipt', amount: 2100, balance: 63800 },
  { id: 'c3', date: '25 Jun 2026', particulars: 'Loan disbursed — Gowramma', type: 'payment', amount: 20000, balance: 61700 },
  { id: 'c4', date: '21 Jun 2026', particulars: 'Weekly savings collection', type: 'receipt', amount: 4200, balance: 81700 },
  { id: 'c5', date: '18 Jun 2026', particulars: 'Bank deposit', type: 'payment', amount: 30000, balance: 77500 },
  { id: 'c6', date: '14 Jun 2026', particulars: 'Weekly savings collection', type: 'receipt', amount: 4000, balance: 107500 },
  { id: 'c7', date: '10 Jun 2026', particulars: 'Meeting refreshment expense', type: 'payment', amount: 450, balance: 103500 },
]

export const bankAccount = {
  balance: 214600,
  lastTransactionDate: '28 Jun 2026',
  transactions: [
    { id: 'b1', date: '25 Jun 2026', desc: 'NEFT — Loan disbursement', amount: -20000 },
    { id: 'b2', date: '18 Jun 2026', desc: 'Cash deposit', amount: 30000 },
    { id: 'b3', date: '10 Jun 2026', desc: 'Interest credited', amount: 620 },
    { id: 'b4', date: '02 Jun 2026', desc: 'NEFT — Loan disbursement', amount: -12000 },
  ],
}

export const auditRecords = [
  { id: 'a1', type: 'Internal', title: 'Q1 FY 2026-27 Internal Audit', date: '15 May 2026', status: 'Clean', auditor: 'CRP — Sunitha Rao' },
  { id: 'a2', type: 'External', title: 'Annual External Audit FY 2025-26', date: '30 Mar 2026', status: 'Clean', auditor: 'District Audit Team' },
  { id: 'a3', type: 'Internal', title: 'Q4 FY 2025-26 Internal Audit', date: '10 Feb 2026', status: 'Minor observations', auditor: 'CRP — Sunitha Rao' },
]
