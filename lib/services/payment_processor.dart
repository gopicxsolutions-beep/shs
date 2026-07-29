/// Abstraction over a real payment gateway (UPI/card processor). No real
/// gateway is wired yet. **Correction (gap-hunt iteration 29)**: swapping in
/// a real gateway is NOT a pure one-file change as this comment used to
/// claim — every real UPI/card gateway settles asynchronously (a webhook
/// callback after the user leaves the app), and `supabase/functions/
/// payment-webhook-handler` already assumes exactly that flow (it only ever
/// transitions a row FROM `status = 'pending'`). But no code path today ever
/// inserts a `'pending'` row — `PaymentRepository.pay()` always awaits
/// `charge()` synchronously and writes a final `'success'`/`'failed'` status
/// in one step, which only a fully-synchronous mock processor can honestly
/// support. A real integration therefore also requires reworking
/// `PaymentRepository.pay()` to write an initial `'pending'` row and stop
/// awaiting a synchronous final result in the UI — a second file, not just
/// this one. See docs/DEVELOPMENT_PROGRESS.md's "External API abstraction
/// plan".
abstract class PaymentProcessor {
  Future<PaymentChargeResult> charge({required num amount, required String mode});
}

class PaymentChargeResult {
  final bool success;
  final String reference;
  const PaymentChargeResult({required this.success, required this.reference});
}

/// Succeeds and synthesizes a plausible reference number for every normal
/// amount, so the rest of the payments flow (recording the attempt, showing
/// history) is fully real and testable without live gateway credentials.
///
/// [declineTestAmount] is a reserved "magic" amount that deterministically
/// simulates a gateway decline instead — the same convention real payment
/// gateways' sandboxes use (e.g. Stripe/Razorpay test docs reserve specific
/// magic values to force a given outcome) so this app's own failure-handling
/// UI (`payments_qr_page.dart`'s "Payment failed" branch, and
/// `PaymentRepository`'s `status: 'failed'` write) can be deliberately and
/// repeatably exercised by QA/tests instead of relying on a random or
/// network-conditioned failure rate that nobody could reliably trigger. ₹1
/// is chosen because it's far below any realistic real payment in this
/// app's domain (loan EMIs, marketplace purchases, membership fees), so a
/// genuine user payment colliding with it is effectively impossible; every
/// other amount keeps behaving exactly as before this change.
class MockPaymentProcessor implements PaymentProcessor {
  static const declineTestAmount = 1;

  @override
  Future<PaymentChargeResult> charge({required num amount, required String mode}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final reference = 'MOCK${DateTime.now().millisecondsSinceEpoch}';
    final success = amount != declineTestAmount;
    return PaymentChargeResult(success: success, reference: reference);
  }
}
