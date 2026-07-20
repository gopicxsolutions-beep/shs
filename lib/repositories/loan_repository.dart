import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/loans.dart' as mock;
import '../data/members.dart' as mock_members;
import '../models/loan.dart';
import '../models/types.dart';
import '../services/supabase_service.dart';

/// Backed by `public.loans` / `public.loan_payments` when Supabase is
/// configured; falls back to `lib/data/loans.dart` otherwise (same dual-mode
/// pattern as [SavingsRepository]).
class LoanRepository {
  SupabaseClient get _client => SupabaseService.instance.client;
  bool get _live => SupabaseService.isConfigured;

  // Demo mode has no backing table, so applying/approving/rejecting/paying
  // would otherwise never show anywhere — track them here so they survive
  // for the rest of the session, mirroring
  // AnnouncementRepository._locallyRead. _locallyUpdated overrides an
  // existing mock loan's fields (by id); _locallyApplied holds brand-new
  // applications not present in the mock catalog at all.
  static final List<Loan> _locallyApplied = [];
  static final Map<String, Loan> _locallyUpdated = {};
  static final Map<String, List<LoanPayment>> _locallyPayments = {};

  List<Loan> _demoLoans() => [
        ..._mockLoans().map((l) => _locallyUpdated[l.id] ?? l),
        ..._locallyApplied.map((l) => _locallyUpdated[l.id] ?? l),
      ];

  Future<List<Loan>> fetchForShg(String? shgId) async {
    if (!_live) return _demoLoans();
    if (shgId == null) return [];
    final rows = await _client.from('loans').select('*, profiles(name)').eq('shg_id', shgId).order('created_at', ascending: false);
    return (rows as List).map((r) => Loan.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<List<Loan>> fetchForMember(String? memberId) async {
    // Demo mode has no real per-member session, so `_mockLoans()` is scoped
    // to the requested member's own loans (resolved to a name since the mock
    // data keys on memberName, not id) rather than returning everyone's —
    // otherwise a member would see the whole SHG's loans as their own, and a
    // leader opening any member's detail page would see the same mixed
    // total for every member.
    if (!_live) return _demoLoans().where((l) => l.memberName == _demoMemberName(memberId)).toList();
    if (memberId == null) return [];
    final rows = await _client.from('loans').select('*, profiles(name)').eq('member_id', memberId).order('created_at', ascending: false);
    return (rows as List).map((r) => Loan.fromMap(r as Map<String, dynamic>)).toList();
  }

  String _demoMemberName(String? memberId) {
    if (memberId == null) return defaultUser.name;
    final match = mock_members.members.where((m) => m.id == memberId);
    return match.isEmpty ? defaultUser.name : match.first.name;
  }

  Future<Loan?> fetchById(String id) async {
    if (!_live) {
      final matches = _demoLoans().where((l) => l.id == id);
      return matches.isEmpty ? null : matches.first;
    }
    final row = await _client.from('loans').select('*, profiles(name)').eq('id', id).maybeSingle();
    return row == null ? null : Loan.fromMap(row);
  }

  /// Returns whether the application was actually saved — `false` (not
  /// an exception) when the applying member/staff has no SHG, so the
  /// caller can tell that apart from a genuine success instead of
  /// showing "submitted for review" for a write that never happened.
  Future<bool> apply({
    required String? memberId,
    required String? shgId,
    required String purpose,
    required num amount,
    required int tenureMonths,
  }) async {
    if (!_live) {
      _locallyApplied.add(Loan(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        memberId: memberId ?? 'me',
        memberName: _demoMemberName(memberId),
        purpose: purpose,
        amount: amount,
        outstanding: amount,
        emi: 0,
        tenureMonths: tenureMonths,
        disbursedOn: null,
        status: 'pending',
        nextDueDate: null,
      ));
      return true;
    }
    if (memberId == null || shgId == null) return false;
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
    return true;
  }

  Future<void> approve(String id, {required num emi, required DateTime nextDueDate}) async {
    if (!_live) {
      final current = _demoLoans().where((l) => l.id == id);
      if (current.isEmpty) return;
      final l = current.first;
      _locallyUpdated[id] = Loan(
        id: l.id,
        memberId: l.memberId,
        memberName: l.memberName,
        purpose: l.purpose,
        amount: l.amount,
        outstanding: l.outstanding,
        emi: emi,
        tenureMonths: l.tenureMonths,
        disbursedOn: DateTime.now(),
        status: 'active',
        nextDueDate: nextDueDate,
      );
      return;
    }
    await _client.from('loans').update({
      'status': 'active',
      'disbursed_on': DateTime.now().toIso8601String().split('T').first,
      'emi': emi,
      'next_due_date': nextDueDate.toIso8601String().split('T').first,
    }).eq('id', id);
  }

  Future<void> reject(String id) async {
    if (!_live) {
      final current = _demoLoans().where((l) => l.id == id);
      if (current.isEmpty) return;
      final l = current.first;
      _locallyUpdated[id] = Loan(
        id: l.id,
        memberId: l.memberId,
        memberName: l.memberName,
        purpose: l.purpose,
        amount: l.amount,
        outstanding: l.outstanding,
        emi: l.emi,
        tenureMonths: l.tenureMonths,
        disbursedOn: l.disbursedOn,
        status: 'rejected',
        nextDueDate: l.nextDueDate,
      );
      return;
    }
    await _client.from('loans').update({'status': 'rejected'}).eq('id', id);
  }

  Future<List<LoanPayment>> fetchPayments(String loanId) async {
    if (!_live) return _locallyPayments[loanId] ?? const [];
    final rows = await _client.from('loan_payments').select().eq('loan_id', loanId).order('paid_on', ascending: false);
    return (rows as List).map((r) => LoanPayment.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Records an EMI payment and updates the loan's outstanding balance,
  /// closing it once fully repaid.
  Future<void> recordPayment(String loanId, num amount, num newOutstanding) async {
    if (!_live) {
      _locallyPayments.putIfAbsent(loanId, () => []).insert(0, LoanPayment(
            id: 'local-${DateTime.now().microsecondsSinceEpoch}',
            loanId: loanId,
            amount: amount,
            paidOn: DateTime.now(),
          ));
      final current = _demoLoans().where((l) => l.id == loanId);
      if (current.isNotEmpty) {
        final l = current.first;
        _locallyUpdated[loanId] = Loan(
          id: l.id,
          memberId: l.memberId,
          memberName: l.memberName,
          purpose: l.purpose,
          amount: l.amount,
          outstanding: newOutstanding,
          emi: l.emi,
          tenureMonths: l.tenureMonths,
          disbursedOn: l.disbursedOn,
          status: newOutstanding <= 0 ? 'closed' : l.status,
          nextDueDate: l.nextDueDate,
        );
      }
      return;
    }
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
