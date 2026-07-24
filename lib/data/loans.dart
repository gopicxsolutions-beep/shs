class Loan {
  final String id;
  final String memberName;
  final String purpose;
  final int amount;
  final int outstanding;
  final int emi;
  final int tenureMonths;
  final String disbursedOn;
  final String status; // pending | approved | rejected | active | closed | overdue
  final String? nextDueDate;
  const Loan({
    required this.id,
    required this.memberName,
    required this.purpose,
    required this.amount,
    required this.outstanding,
    required this.emi,
    required this.tenureMonths,
    required this.disbursedOn,
    required this.status,
    this.nextDueDate,
  });
}

const loans = <Loan>[
  Loan(id: 'l1', memberName: 'Lakshmi Devi', purpose: 'Dairy — buy milch cow', amount: 30000, outstanding: 22000, emi: 2500, tenureMonths: 12, disbursedOn: '10 Jan 2026', status: 'active', nextDueDate: '10 Jul 2026'),
  Loan(id: 'l2', memberName: 'Rajeshwari', purpose: 'Tailoring machine purchase', amount: 25000, outstanding: 18500, emi: 2100, tenureMonths: 12, disbursedOn: '05 Feb 2026', status: 'active', nextDueDate: '05 Jul 2026'),
  Loan(id: 'l3', memberName: 'Bhavani', purpose: 'Kirana shop working capital', amount: 15000, outstanding: 12000, emi: 1300, tenureMonths: 12, disbursedOn: '20 Mar 2026', status: 'active', nextDueDate: '20 Jul 2026'),
  Loan(id: 'l4', memberName: 'Durga Bhavani', purpose: 'Poultry farming', amount: 12000, outstanding: 9000, emi: 1000, tenureMonths: 12, disbursedOn: '15 Apr 2026', status: 'overdue', nextDueDate: '15 Jun 2026'),
  Loan(id: 'l5', memberName: 'Gowramma', purpose: 'Agriculture inputs — seeds & fertiliser', amount: 20000, outstanding: 15500, emi: 1700, tenureMonths: 12, disbursedOn: '02 May 2026', status: 'active', nextDueDate: '02 Jul 2026'),
  Loan(id: 'l6', memberName: 'Jyothi', purpose: 'Handicraft raw material', amount: 10000, outstanding: 8000, emi: 900, tenureMonths: 12, disbursedOn: '18 May 2026', status: 'active', nextDueDate: '18 Jul 2026'),
  // Disbursed on 25 Jun 2026 (see financial.dart's f2 ledger entry — "Loan
  // disbursed — Anasuya", debit 35000, same date/amount) — this must stay in
  // sync with 'active'/disbursedOn/emi/nextDueDate, and members.dart's m4
  // (Anasuya) loanOutstanding must keep matching this loan's outstanding.
  Loan(id: 'l7', memberName: 'Anasuya', purpose: 'Food processing unit expansion', amount: 35000, outstanding: 35000, emi: 2000, tenureMonths: 18, disbursedOn: '25 Jun 2026', status: 'active', nextDueDate: '25 Jul 2026'),
  Loan(id: 'l8', memberName: 'Hemalatha', purpose: 'Vegetable vending cart', amount: 8000, outstanding: 8000, emi: 0, tenureMonths: 10, disbursedOn: '', status: 'pending'),
];
