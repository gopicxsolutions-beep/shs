/// Abstraction over a real payment gateway (UPI/card processor). No real
/// gateway is wired yet — a production key would swap [MockPaymentProcessor]
/// for a real implementation of this same interface without touching any
/// call site. See docs/DEVELOPMENT_PROGRESS.md's "External API abstraction
/// plan".
abstract class PaymentProcessor {
  Future<PaymentChargeResult> charge({required num amount, required String mode});
}

class PaymentChargeResult {
  final bool success;
  final String reference;
  const PaymentChargeResult({required this.success, required this.reference});
}

/// Always succeeds and synthesizes a plausible reference number, so the
/// rest of the payments flow (recording the attempt, showing history) is
/// fully real and testable without live gateway credentials.
class MockPaymentProcessor implements PaymentProcessor {
  @override
  Future<PaymentChargeResult> charge({required num amount, required String mode}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final reference = 'MOCK${DateTime.now().millisecondsSinceEpoch}';
    return PaymentChargeResult(success: true, reference: reference);
  }
}
