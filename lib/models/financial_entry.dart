/// Mirrors a row in `public.financial_ledger`.
class FinancialEntry {
  final String id;
  final String entryType; // cashbook | ledger | bank | audit
  final String description;
  final num debit;
  final num credit;
  final num balance;
  final DateTime date;
  final String? createdByName;
  // Only populated when the query joins `shgs(name)` (today: only
  // FinancialRepository.fetchAllForStaff()'s platform-wide fetch) — null
  // everywhere else, including demo mode. Mirrors Loan.shgName. Needed here
  // more than in Loans/Savings/Livelihood: `balance` is a per-SHG running
  // total, so a flat cross-SHG list without this tag would show the number
  // jumping between unrelated SHGs' balances with no visible explanation.
  final String? shgName;

  const FinancialEntry({
    required this.id,
    required this.entryType,
    required this.description,
    required this.debit,
    required this.credit,
    required this.balance,
    required this.date,
    this.createdByName,
    this.shgName,
  });

  factory FinancialEntry.fromMap(Map<String, dynamic> map) => FinancialEntry(
        id: map['id'] as String,
        entryType: map['entry_type'] as String,
        description: map['description'] as String,
        debit: map['debit'] as num? ?? 0,
        credit: map['credit'] as num? ?? 0,
        balance: map['balance'] as num? ?? 0,
        date: DateTime.parse(map['entry_date'] as String),
        createdByName: (map['profiles'] as Map<String, dynamic>?)?['name'] as String?,
        shgName: (map['shgs'] as Map<String, dynamic>?)?['name'] as String?,
      );
}
