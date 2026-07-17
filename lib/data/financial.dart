class FinancialLedgerEntry {
  final String id;
  final String entryType; // cashbook | ledger | bank | audit
  final String description;
  final int debit;
  final int credit;
  final int balance;
  final String date;
  const FinancialLedgerEntry({
    required this.id,
    required this.entryType,
    required this.description,
    required this.debit,
    required this.credit,
    required this.balance,
    required this.date,
  });
}

const financialLedgerEntries = <FinancialLedgerEntry>[
  FinancialLedgerEntry(id: 'f1', entryType: 'cashbook', description: 'Weekly savings collection', debit: 0, credit: 4500, balance: 486200, date: '28 Jun 2026'),
  FinancialLedgerEntry(id: 'f2', entryType: 'cashbook', description: 'Loan disbursed — Anasuya', debit: 35000, credit: 0, balance: 481700, date: '25 Jun 2026'),
  FinancialLedgerEntry(id: 'f3', entryType: 'ledger', description: 'Interest accrued on group loans', debit: 0, credit: 1200, balance: 312000, date: '20 Jun 2026'),
  FinancialLedgerEntry(id: 'f4', entryType: 'bank', description: 'Bank deposit — savings pooled', debit: 0, credit: 20000, balance: 244600, date: '18 Jun 2026'),
  FinancialLedgerEntry(id: 'f5', entryType: 'bank', description: 'Bank charges', debit: 150, credit: 0, balance: 224600, date: '15 Jun 2026'),
  FinancialLedgerEntry(id: 'f6', entryType: 'audit', description: 'FY 2025-26 audit adjustment', debit: 0, credit: 800, balance: 486200, date: '30 Mar 2026'),
];
