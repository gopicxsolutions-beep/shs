export interface Transaction {
  id: string
  member: string
  type: 'Savings' | 'Loan EMI'
  amount: number
  date: string
  mode: 'UPI'
  txnId: string
}

export const recentTransactions: Transaction[] = [
  { id: 't1', member: 'Lakshmi Devi', type: 'Savings', amount: 500, date: '28 Jun 2026', mode: 'UPI', txnId: 'UPI2606281145879231' },
  { id: 't2', member: 'Rajeshwari', type: 'Loan EMI', amount: 2100, date: '27 Jun 2026', mode: 'UPI', txnId: 'UPI2606271032441087' },
  { id: 't3', member: 'Anasuya', type: 'Savings', amount: 500, date: '26 Jun 2026', mode: 'UPI', txnId: 'UPI2606260918225643' },
  { id: 't4', member: 'Bhavani', type: 'Loan EMI', amount: 1300, date: '24 Jun 2026', mode: 'UPI', txnId: 'UPI2606240756119284' },
  { id: 't5', member: 'Padma Reddy', type: 'Savings', amount: 500, date: '21 Jun 2026', mode: 'UPI', txnId: 'UPI2606211203337765' },
  { id: 't6', member: 'Gowramma', type: 'Loan EMI', amount: 1700, date: '20 Jun 2026', mode: 'UPI', txnId: 'UPI2606200845561209' },
  { id: 't7', member: 'Chandrakala', type: 'Savings', amount: 400, date: '18 Jun 2026', mode: 'UPI', txnId: 'UPI2606180712983340' },
  { id: 't8', member: 'Jyothi', type: 'Loan EMI', amount: 900, date: '15 Jun 2026', mode: 'UPI', txnId: 'UPI2606150934471256' },
]
