import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/payments.dart' as mock;
import '../models/payment.dart';
import '../services/payment_processor.dart';
import '../services/supabase_service.dart';

/// Backed by `public.payments` when Supabase is configured; falls back to
/// `lib/data/payments.dart` otherwise. Actual money movement goes through
/// [PaymentProcessor] (mocked until a real gateway key is supplied) — this
/// repository only ever records the *result* of that call.
class PaymentRepository {
  PaymentRepository({PaymentProcessor? processor}) : _processor = processor ?? MockPaymentProcessor();

  final PaymentProcessor _processor;
  SupabaseClient get _client => SupabaseService.instance.client;
  bool get _live => SupabaseService.isConfigured;

  // Demo mode has no backing table, so a completed payment would otherwise
  // never show up in Recent Payments / History despite the immediate
  // success toast — track it here so it survives for the rest of the
  // session, mirroring AnnouncementRepository._locallyRead.
  static final List<Payment> _locallyAdded = [];

  Future<List<Payment>> fetchHistory(String? memberId) async {
    if (!_live) {
      return [
        ..._locallyAdded.reversed,
        ...mock.paymentsHistory.map((p) => Payment(id: p.id, amount: p.amount, mode: p.mode, reference: p.reference, status: p.status, createdAt: _parseMockDate(p.date))),
      ];
    }
    if (memberId == null) return [];
    final rows = await _client.from('payments').select().eq('member_id', memberId).order('created_at', ascending: false);
    return (rows as List).map((r) => Payment.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Runs the (mock) gateway charge, then records the outcome. Returns the
  /// result so the UI can show success/failure immediately.
  ///
  /// In live mode, a missing [memberId] (profile not yet loaded) must be
  /// checked *before* invoking the processor: charging first and then
  /// discovering there's nowhere to record the result used to return the
  /// processor's own (always-successful, for the mock) outcome unchanged —
  /// so the UI showed "Payment successful · Ref ..." for a payment that was
  /// never written to `payments` at all, the same false-success shape fixed
  /// for `LoanRepository.apply()`'s no-SHG case.
  Future<PaymentChargeResult> pay({required String? memberId, required num amount, required String mode}) async {
    if (_live && memberId == null) {
      return const PaymentChargeResult(success: false, reference: '');
    }
    final result = await _processor.charge(amount: amount, mode: mode);
    if (!_live) {
      _locallyAdded.add(Payment(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        amount: amount,
        mode: mode,
        reference: result.reference,
        status: result.success ? 'success' : 'failed',
        createdAt: DateTime.now(),
      ));
      return result;
    }
    await _client.from('payments').insert({
      'member_id': memberId,
      'amount': amount,
      'mode': mode,
      'reference': result.reference,
      'status': result.success ? 'success' : 'failed',
    });
    return result;
  }

  DateTime _parseMockDate(String s) {
    try {
      return DateFormat('dd MMM yyyy').parse(s);
    } catch (_) {
      return DateTime.now();
    }
  }
}
