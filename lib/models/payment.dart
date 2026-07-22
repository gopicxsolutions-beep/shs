/// Mirrors a row in `public.payments`.
class Payment {
  final String id;
  final num amount;
  final String mode; // UPI | QR | Card | NetBanking
  final String? reference;
  final String status; // pending | success | failed
  final DateTime createdAt;

  const Payment({
    required this.id,
    required this.amount,
    required this.mode,
    this.reference,
    required this.status,
    required this.createdAt,
  });

  factory Payment.fromMap(Map<String, dynamic> map) => Payment(
        id: map['id'] as String,
        amount: map['amount'] as num,
        mode: map['mode'] as String,
        reference: map['reference'] as String?,
        status: map['status'] as String,
        // `created_at` is `timestamptz` (UTC). Convert to local (IST) at the
        // parse boundary so the date-only `DateFormat` display never shows
        // the wrong calendar day for a payment made near local midnight.
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      );
}
