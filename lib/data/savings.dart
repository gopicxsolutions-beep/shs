class SavingsEntry {
  final String id;
  final String memberName;
  final String date;
  final int amount;
  final String mode; // Cash | UPI | Bank Transfer
  final String type; // Weekly | Monthly | Daily
  final String status; // verified | pending
  const SavingsEntry({
    required this.id,
    required this.memberName,
    required this.date,
    required this.amount,
    required this.mode,
    required this.type,
    required this.status,
  });
}

const savingsEntries = <SavingsEntry>[
  SavingsEntry(id: 's1', memberName: 'Lakshmi Devi', date: '28 Jun 2026', amount: 500, mode: 'UPI', type: 'Weekly', status: 'verified'),
  SavingsEntry(id: 's2', memberName: 'Padma Reddy', date: '28 Jun 2026', amount: 500, mode: 'Cash', type: 'Weekly', status: 'verified'),
  SavingsEntry(id: 's3', memberName: 'Rajeshwari', date: '28 Jun 2026', amount: 300, mode: 'Cash', type: 'Weekly', status: 'verified'),
  SavingsEntry(id: 's4', memberName: 'Anasuya', date: '28 Jun 2026', amount: 500, mode: 'UPI', type: 'Weekly', status: 'pending'),
  SavingsEntry(id: 's5', memberName: 'Bhavani', date: '21 Jun 2026', amount: 500, mode: 'Cash', type: 'Weekly', status: 'verified'),
  SavingsEntry(id: 's6', memberName: 'Chandrakala', date: '21 Jun 2026', amount: 400, mode: 'Bank Transfer', type: 'Weekly', status: 'verified'),
  SavingsEntry(id: 's7', memberName: 'Durga Bhavani', date: '21 Jun 2026', amount: 300, mode: 'Cash', type: 'Weekly', status: 'verified'),
  SavingsEntry(id: 's8', memberName: 'Eswari', date: '14 Jun 2026', amount: 500, mode: 'UPI', type: 'Weekly', status: 'verified'),
];

const savingsMonthlyTrend = <(String, num)>[
  ('Jan', 32000), ('Feb', 35500), ('Mar', 34000), ('Apr', 38200), ('May', 41000), ('Jun', 44500),
];
