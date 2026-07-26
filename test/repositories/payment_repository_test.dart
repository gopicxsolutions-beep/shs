import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/repositories/payment_repository.dart';
import 'package:shg_saathi/services/payment_processor.dart';
import 'package:shg_saathi/services/supabase_service.dart';

/// Regression coverage for `PaymentRepository.pay()`'s demo-mode recording
/// path, on both the success and failure branches.
///
/// `MockPaymentProcessor`'s reserved decline amount
/// (`MockPaymentProcessor.declineTestAmount`) exists specifically so a
/// gateway decline is deterministically reproducible instead of never
/// happening at all — but `payment_processor_test.dart` only proves the
/// processor's own `charge()` return value flips to `success: false`. It
/// does not touch `PaymentRepository`, which is the layer that actually
/// turns that result into a `status: 'failed'` record
/// (`payments_qr_page.dart`'s "Payment failed" SnackBar reads from this same
/// repository call). Without this file, the repository's failure-recording
/// branch — `status: result.success ? 'success' : 'failed'` — had never
/// been exercised by any test, live session, or previous round of this
/// project's testing despite the mechanism existing to make it possible.
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  group('PaymentRepository.pay (demo mode)', () {
    test('a normal amount succeeds and is recorded with status success', () async {
      final repo = PaymentRepository();
      final result = await repo.pay(memberId: 'mem-test', amount: 500, mode: 'UPI');
      expect(result.success, isTrue);
      expect(result.reference, isNotEmpty);

      final history = await repo.fetchHistory('mem-test');
      final recorded = history.firstWhere((p) => p.reference == result.reference);
      expect(recorded.status, 'success');
      expect(recorded.amount, 500);
      expect(recorded.mode, 'UPI');
    });

    test('the reserved decline amount fails and is recorded with status failed', () async {
      final repo = PaymentRepository();
      final result = await repo.pay(
        memberId: 'mem-test',
        amount: MockPaymentProcessor.declineTestAmount,
        mode: 'UPI',
      );
      expect(result.success, isFalse);
      // Even a decline still carries a reference, mirroring a real gateway's
      // decline response (which still has a transaction id) — this is what
      // lets the repository still write a real, traceable 'failed' row
      // instead of silently dropping the attempt.
      expect(result.reference, isNotEmpty);

      final history = await repo.fetchHistory('mem-test');
      final recorded = history.firstWhere((p) => p.reference == result.reference);
      expect(recorded.status, 'failed');
      expect(recorded.amount, MockPaymentProcessor.declineTestAmount);
    });

    test('every other amount around the reserved value keeps succeeding', () async {
      final repo = PaymentRepository();
      for (final amount in [2, 10, 1000000]) {
        final result = await repo.pay(memberId: 'mem-test', amount: amount, mode: 'Card');
        expect(result.success, isTrue, reason: 'amount $amount should still succeed and be recorded as such');
      }
    });
  });
}
