/// Mirrors a row in `public.financial_ledger`.
class FinancialEntry {
  final String id;
  final String entryType; // cashbook | ledger | bank | audit
  final String description;
  final num debit;
  final num credit;
  final num balance;
  final DateTime date;

  const FinancialEntry({
    required this.id,
    required this.entryType,
    required this.description,
    required this.debit,
    required this.credit,
    required this.balance,
    required this.date,
  });

  factory FinancialEntry.fromMap(Map<String, dynamic> map) => FinancialEntry(
        id: map['id'] as String,
        entryType: map['entry_type'] as String,
        description: map['description'] as String,
        debit: map['debit'] as num? ?? 0,
        credit: map['credit'] as num? ?? 0,
        balance: map['balance'] as num? ?? 0,
        date: DateTime.parse(map['entry_date'] as String),
      );
}
