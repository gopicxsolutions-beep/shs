import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/services/payment_processor.dart';

/// Regression coverage for a real, session-long gap: `MockPaymentProcessor`
/// previously always returned `success: true` for every amount, so no test
/// or live session ever exercised the app's own failure-handling code paths
/// (`payments_qr_page.dart`'s "Payment failed" branch, and
/// `PaymentRepository`'s `status: 'failed'` write). A reserved "magic" test
/// amount now deterministically declines, mirroring how real payment
/// gateway sandboxes make failure scenarios reproducible, without changing
/// behavior for any normal amount.
void main() {
  group('MockPaymentProcessor', () {
    final processor = MockPaymentProcessor();

    test('succeeds for a normal amount and returns a populated reference', () async {
      final result = await processor.charge(amount: 500, mode: 'UPI');
      expect(result.success, isTrue);
      expect(result.reference, isNotEmpty);
      expect(result.reference, startsWith('MOCK'));
    });

    test('deterministically declines the reserved test amount so the failure path is testable', () async {
      final result = await processor.charge(amount: MockPaymentProcessor.declineTestAmount, mode: 'UPI');
      expect(result.success, isFalse);
      // Even a decline still carries a reference, mirroring a real gateway's
      // decline response (which still has a transaction id) — this is what
      // lets PaymentRepository still write a real, traceable 'failed' row.
      expect(result.reference, isNotEmpty);
    });

    test('every other amount keeps succeeding exactly as before this change', () async {
      for (final amount in [2, 10, 75, 500, 999999]) {
        final result = await processor.charge(amount: amount, mode: 'Card');
        expect(result.success, isTrue, reason: 'amount $amount should still succeed');
      }
    });
  });
}
