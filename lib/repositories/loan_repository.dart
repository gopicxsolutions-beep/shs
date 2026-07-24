import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/loans.dart' as mock;
import '../data/members.dart' as mock_members;
import '../models/loan.dart';
import '../models/types.dart';
import '../services/supabase_service.dart';

/// Thrown by [LoanRepository.approve]/[LoanRepository.reject] when the loan
/// is no longer 'pending' by the time the write reaches the database — i.e.
/// a different leader/staff account already decided it (see
/// `approve_loan`/`reject_loan` in
/// supabase/migrations/0029_loan_and_scheme_decision_race_guard.sql). Lets
/// the UI show a specific "someone already acted on this" message instead
/// of a generic failure.
class LoanAlreadyDecidedException implements Exception {
  const LoanAlreadyDecidedException();
}

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

  // Test-only seam (null by default, so every existing test keeps seeing
  // the exact short mock.loans it always has).
  // test/routes/long_content_stress_test.dart sets this to exercise a
  // realistic long loan purpose at a normal viewport, then resets it — no
  // change to lib/data/loans.dart's shared mock records themselves.
  static List<mock.Loan>? debugLoansOverride;

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
    // Atomic via `approve_loan` (see
    // supabase/migrations/0029_loan_and_scheme_decision_race_guard.sql) —
    // locks the row and verifies it's still 'pending' before transitioning,
    // so a second leader/staff account racing to approve/reject the same
    // loan (both looking at the same "pending" queue) can no longer
    // silently overwrite the first decision or re-disburse with different
    // terms.
    try {
      await _client.rpc('approve_loan', params: {
        'p_loan_id': id,
        'p_emi': emi,
        'p_next_due_date': nextDueDate.toIso8601String().split('T').first,
      });
    } on PostgrestException catch (e) {
      // 'PGRST202' = function not found in schema cache — migration 0029
      // not deployed yet. Falls back to the old non-atomic write rather
      // than hard-failing every approval in the gap before it's deployed
      // (same fallback shape as `recordPayment`'s PGRST202 handling above).
      if (e.code == 'PGRST202') {
        await _client.from('loans').update({
          'status': 'active',
          'disbursed_on': DateTime.now().toIso8601String().split('T').first,
          'emi': emi,
          'next_due_date': nextDueDate.toIso8601String().split('T').first,
        }).eq('id', id);
        return;
      }
      if (e.message.contains('no longer pending')) throw const LoanAlreadyDecidedException();
      rethrow;
    }
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
    // Atomic via `reject_loan` — see the comment on approve() above for why.
    try {
      await _client.rpc('reject_loan', params: {'p_loan_id': id});
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST202') {
        await _client.from('loans').update({'status': 'rejected'}).eq('id', id);
        return;
      }
      if (e.message.contains('no longer pending')) throw const LoanAlreadyDecidedException();
      rethrow;
    }
  }

  Future<List<LoanPayment>> fetchPayments(String loanId) async {
    if (!_live) return _locallyPayments[loanId] ?? const [];
    final rows = await _client.from('loan_payments').select().eq('loan_id', loanId).order('paid_on', ascending: false);
    return (rows as List).map((r) => LoanPayment.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Records an EMI payment and updates the loan's outstanding balance,
  /// closing it once fully repaid. [newOutstanding] is only used in demo
  /// mode (no real backend to compute against) — in live mode the new
  /// balance is always computed atomically server-side (see
  /// `record_loan_payment` in
  /// supabase/migrations/0011_atomic_loan_payment_and_ledger_balance.sql),
  /// never from this caller-supplied value. This used to write the
  /// caller's own precomputed `newOutstanding` directly — a real race: two
  /// leader/staff accounts (both allowed to update the same loan per
  /// `loans_update_leader_or_staff`) recording a payment around the same
  /// time would each compute from the same stale `loan.outstanding`
  /// snapshot, and whichever write landed second would silently overwrite
  /// (not add to) the first payment's effect on the balance.
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
    // Atomic via `record_loan_payment` (see
    // supabase/migrations/0011_atomic_loan_payment_and_ledger_balance.sql)
    // — inserts the payment row and decrements `outstanding` in one
    // statement/transaction, so a concurrent second payment on the same
    // loan correctly computes from the post-first-payment balance instead
    // of the same stale snapshot both callers happened to load.
    try {
      await _client.rpc('record_loan_payment', params: {'p_loan_id': loanId, 'p_amount': amount});
    } on PostgrestException catch (e) {
      // 'PGRST202' = PostgREST's "function not found in schema cache" —
      // the migration above hasn't been deployed yet. Falls back to the
      // old non-atomic behavior (same race this fix closes) rather than
      // hard-failing every payment in the gap before the migration runs;
      // remove once the migration is confirmed deployed everywhere this
      // app runs. (Checking 'PGRST202', not the raw Postgres '42883' —
      // this session shipped that exact wrong check once already on the
      // marketplace fix and had to live-debug it; see that fix's comment
      // for the full story.)
      if (e.code != 'PGRST202') rethrow;
      await _client.from('loan_payments').insert({'loan_id': loanId, 'amount': amount});
      await _client.from('loans').update({
        'outstanding': newOutstanding,
        if (newOutstanding <= 0) 'status': 'closed',
      }).eq('id', loanId);
    }
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
  List<Loan> _mockLoans() => (debugLoansOverride ?? mock.loans).reversed
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
