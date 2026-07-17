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

  Future<List<Payment>> fetchHistory(String? memberId) async {
    if (!_live || memberId == null) {
      return mock.paymentsHistory.map((p) => Payment(id: p.id, amount: p.amount, mode: p.mode, reference: p.reference, status: p.status, createdAt: _parseMockDate(p.date))).toList();
    }
    final rows = await _client.from('payments').select().eq('member_id', memberId).order('created_at', ascending: false);
    return (rows as List).map((r) => Payment.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Runs the (mock) gateway charge, then records the outcome. Returns the
  /// result so the UI can show success/failure immediately.
  Future<PaymentChargeResult> pay({required String? memberId, required num amount, required String mode}) async {
    final result = await _processor.charge(amount: amount, mode: mode);
    if (!_live || memberId == null) return result;
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
