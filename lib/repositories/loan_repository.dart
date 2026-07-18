import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/loans.dart' as mock;
import '../models/loan.dart';
import '../services/supabase_service.dart';

/// Backed by `public.loans` / `public.loan_payments` when Supabase is
/// configured; falls back to `lib/data/loans.dart` otherwise (same dual-mode
/// pattern as [SavingsRepository]).
class LoanRepository {
  SupabaseClient get _client => SupabaseService.instance.client;
  bool get _live => SupabaseService.isConfigured;

  Future<List<Loan>> fetchForShg(String? shgId) async {
    if (!_live || shgId == null) return _mockLoans();
    final rows = await _client.from('loans').select('*, profiles(name)').eq('shg_id', shgId).order('created_at', ascending: false);
    return (rows as List).map((r) => Loan.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<List<Loan>> fetchForMember(String? memberId) async {
    if (!_live || memberId == null) return _mockLoans();
    final rows = await _client.from('loans').select('*, profiles(name)').eq('member_id', memberId).order('created_at', ascending: false);
    return (rows as List).map((r) => Loan.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<Loan?> fetchById(String id) async {
    if (!_live) {
      final matches = _mockLoans().where((l) => l.id == id);
      return matches.isEmpty ? null : matches.first;
    }
    final row = await _client.from('loans').select('*, profiles(name)').eq('id', id).maybeSingle();
    return row == null ? null : Loan.fromMap(row);
  }

  Future<void> apply({
    required String? memberId,
    required String? shgId,
    required String purpose,
    required num amount,
    required int tenureMonths,
  }) async {
    if (!_live || memberId == null || shgId == null) return;
    await _client.from('loans').insert({
      'member_id': memberId,
      'shg_id': shgId,
      'purpose': purpose,
      'amount': amount,
      'outstanding': amount,
      'emi': 0,
      'tenure_months': tenureMonths,
      'status': 'pending',
    });
  }

  Future<void> approve(String id, {required num emi, required DateTime nextDueDate}) async {
    if (!_live) return;
    await _client.from('loans').update({
      'status': 'active',
      'disbursed_on': DateTime.now().toIso8601String().split('T').first,
      'emi': emi,
      'next_due_date': nextDueDate.toIso8601String().split('T').first,
    }).eq('id', id);
  }

  Future<void> reject(String id) async {
    if (!_live) return;
    await _client.from('loans').update({'status': 'rejected'}).eq('id', id);
  }

  Future<List<LoanPayment>> fetchPayments(String loanId) async {
    if (!_live) return const [];
    final rows = await _client.from('loan_payments').select().eq('loan_id', loanId).order('paid_on', ascending: false);
    return (rows as List).map((r) => LoanPayment.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Records an EMI payment and updates the loan's outstanding balance,
  /// closing it once fully repaid.
  Future<void> recordPayment(String loanId, num amount, num newOutstanding) async {
    if (!_live) return;
    await _client.from('loan_payments').insert({'loan_id': loanId, 'amount': amount});
    await _client.from('loans').update({
      'outstanding': newOutstanding,
      if (newOutstanding <= 0) 'status': 'closed',
    }).eq('id', loanId);
  }

  Stream<List<Loan>> watchForShg(String shgId) {
    return _client
        .from('loans')
        .stream(primaryKey: ['id'])
        .eq('shg_id', shgId)
        .order('created_at')
        .map((rows) => rows.map(Loan.fromMap).toList());
  }

  // Reversed so demo mode matches the live query's `created_at desc` order
  // (newest first) — the mock list is declared oldest-disbursed-first, with
  // the still-pending applications (no disbursedOn yet) last.
  List<Loan> _mockLoans() => mock.loans.reversed
      .map((l) => Loan(
            id: l.id,
            memberId: l.id,
            memberName: l.memberName,
            purpose: l.purpose,
            amount: l.amount,
            outstanding: l.outstanding,
            emi: l.emi,
            tenureMonths: l.tenureMonths,
            disbursedOn: _parseMockDate(l.disbursedOn),
            status: l.status,
            nextDueDate: _parseMockDate(l.nextDueDate),
          ))
      .toList();

  DateTime? _parseMockDate(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return DateFormat('dd MMM yyyy').parse(s);
    } catch (_) {
      return null;
    }
  }
}
