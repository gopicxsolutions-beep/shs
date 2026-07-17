/// Mirrors a row in `public.savings_entries` (joined with the member's name).
class SavingsEntry {
  final String id;
  final String memberId;
  final String memberName;
  final DateTime date;
  final num amount;
  final String mode; // Cash | UPI | Bank Transfer
  final String frequency; // Weekly | Monthly | Daily
  final String status; // verified | pending

  const SavingsEntry({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.date,
    required this.amount,
    required this.mode,
    required this.frequency,
    required this.status,
  });

  factory SavingsEntry.fromMap(Map<String, dynamic> map) => SavingsEntry(
        id: map['id'] as String,
        memberId: map['member_id'] as String,
        memberName: (map['profiles'] as Map<String, dynamic>?)?['name'] as String? ?? 'Member',
        date: DateTime.parse(map['entry_date'] as String),
        amount: map['amount'] as num,
        mode: map['mode'] as String,
        frequency: map['frequency'] as String,
        status: map['status'] as String,
      );
}

class MonthlyTotal {
  final String label;
  final num total;
  const MonthlyTotal(this.label, this.total);
}
