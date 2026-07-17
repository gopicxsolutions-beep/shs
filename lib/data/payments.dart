class PaymentMock {
  final String id;
  final int amount;
  final String mode;
  final String reference;
  final String status;
  final String date;
  const PaymentMock({required this.id, required this.amount, required this.mode, required this.reference, required this.status, required this.date});
}

const paymentsHistory = <PaymentMock>[
  PaymentMock(id: 'pm1', amount: 500, mode: 'UPI', reference: 'UPI2026062801', status: 'success', date: '28 Jun 2026'),
  PaymentMock(id: 'pm2', amount: 2500, mode: 'UPI', reference: 'UPI2026062001', status: 'success', date: '20 Jun 2026'),
  PaymentMock(id: 'pm3', amount: 1000, mode: 'QR', reference: 'QR2026061501', status: 'failed', date: '15 Jun 2026'),
];
