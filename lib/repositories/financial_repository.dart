import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/financial.dart' as mock;
import '../models/financial_entry.dart';
import '../models/paged_result.dart';
import '../services/supabase_service.dart';

/// Backed by `public.financial_ledger` (discriminated by `entry_type`) when
/// Supabase is configured; falls back to `lib/data/financial.dart` otherwise.
class FinancialRepository {
  SupabaseClient get _client => SupabaseService.instance.client;
  bool get _live => SupabaseService.isConfigured;

  // Demo mode has no backing table, so a submitted entry would otherwise
  // vanish the instant the ledger reloads — track it here so it survives
  // for the rest of the session, mirroring AnnouncementRepository._locallyRead.
  static final List<FinancialEntry> _locallyAdded = [];

  // One SHG's cashbook/ledger/bank/audit history accumulates indefinitely
  // over the group's lifetime (years of meetings, each potentially adding
  // entries) — previously hard-capped at a single `.limit(500)` with no
  // pagination at all, silently and permanently hiding anything older than
  // the 500th most-recent row for a long-running SHG (the exact gap
  // AdminUsersPage/AdminShgsPage already fixed for their own lists — see
  // [PagedResult]). Sort key is (`entry_date` desc, `created_at` desc) —
  // entries can be legitimately backdated, so `entry_date` alone isn't a
  // unique cursor; `created_at` is the tiebreaker for entries sharing the
  // same `entry_date`. [afterEntryDate]/[afterCreatedAt] are the last-seen
  // page's final row's own values; the first call omits both. Fetches one
  // extra row beyond [pageSize] to detect `hasMore` without a separate
  // COUNT query, same as AdminRepository.fetchAllUsers.
  Future<PagedResult<FinancialEntry>> fetchForShg(String? shgId, String entryType, {DateTime? afterEntryDate, DateTime? afterCreatedAt, int pageSize = 100}) async {
    if (!_live) {
      final mockEntries = mock.financialLedgerEntries
          .where((e) => e.entryType == entryType)
          .map((e) => FinancialEntry(id: e.id, entryType: e.entryType, description: e.description, debit: e.debit, credit: e.credit, balance: e.balance, date: _parseMockDate(e.date), createdAt: _parseMockDate(e.date)));
      final localEntries = _locallyAdded.where((e) => e.entryType == entryType).toList().reversed;
      return PagedResult(items: [...localEntries, ...mockEntries], hasMore: false);
    }
    if (shgId == null) return const PagedResult(items: [], hasMore: false);
    // `created_by` is the only FK financial_ledger has into `profiles` (no
    // second FK on this table), so this embed is unambiguous to PostgREST —
    // unlike shg_join_requests' member_id/decided_by collision (round 90),
    // this doesn't need an explicit `profiles!created_by(name)` hint.
    var builder = _client.from('financial_ledger').select('*, profiles(name)').eq('shg_id', shgId).eq('entry_type', entryType);
    if (afterEntryDate != null && afterCreatedAt != null) {
      final d = afterEntryDate.toIso8601String().split('T').first;
      final c = afterCreatedAt.toIso8601String();
      builder = builder.or('entry_date.lt.$d,and(entry_date.eq.$d,created_at.lt.$c)');
    }
    final rows = await builder.order('entry_date', ascending: false).order('created_at', ascending: false).limit(pageSize + 1);
    final list = (rows as List).map((r) => FinancialEntry.fromMap(r as Map<String, dynamic>)).toList();
    final hasMore = list.length > pageSize;
    return PagedResult(items: hasMore ? list.sublist(0, pageSize) : list, hasMore: hasMore);
  }

  /// Platform-wide feed for crp/clf/admin — every SHG's entries of this
  /// [entryType], not just one. `financial_ledger_select_shg_or_staff` (RLS)
  /// already grants `is_staff()` an unconditional, unscoped SELECT — mirrors
  /// LoanRepository.fetchAllForStaff()'s round-168 fix. Joins `shgs(name)`
  /// in addition to `profiles(name)`: each row's `balance` is a per-SHG
  /// running total (see `addEntry`'s doc comment), so a flat cross-SHG list
  /// needs the SHG tagged per row or the balance appears to jump around
  /// arbitrarily between unrelated rows. Same pagination shape as
  /// [fetchForShg] above — this feed had the identical unpaginated-cap gap,
  /// worse here since the 500-row cap was shared across every SHG in the
  /// federation combined, not just one.
  Future<PagedResult<FinancialEntry>> fetchAllForStaff(String entryType, {DateTime? afterEntryDate, DateTime? afterCreatedAt, int pageSize = 100}) async {
    if (!_live) {
      final mockEntries = mock.financialLedgerEntries
          .where((e) => e.entryType == entryType)
          .map((e) => FinancialEntry(id: e.id, entryType: e.entryType, description: e.description, debit: e.debit, credit: e.credit, balance: e.balance, date: _parseMockDate(e.date), createdAt: _parseMockDate(e.date)));
      final localEntries = _locallyAdded.where((e) => e.entryType == entryType).toList().reversed;
      return PagedResult(items: [...localEntries, ...mockEntries], hasMore: false);
    }
    var builder = _client.from('financial_ledger').select('*, profiles(name), shgs(name)').eq('entry_type', entryType);
    if (afterEntryDate != null && afterCreatedAt != null) {
      final d = afterEntryDate.toIso8601String().split('T').first;
      final c = afterCreatedAt.toIso8601String();
      builder = builder.or('entry_date.lt.$d,and(entry_date.eq.$d,created_at.lt.$c)');
    }
    final rows = await builder.order('entry_date', ascending: false).order('created_at', ascending: false).limit(pageSize + 1);
    final list = (rows as List).map((r) => FinancialEntry.fromMap(r as Map<String, dynamic>)).toList();
    final hasMore = list.length > pageSize;
    return PagedResult(items: hasMore ? list.sublist(0, pageSize) : list, hasMore: hasMore);
  }

  /// Adds an entry, computing the running balance from the last entry of the
  /// same type (mirrors a simple cashbook: balance = previous ± this entry).
  /// Returns whether the entry was actually saved — `false` (not an
  /// exception) when a live staff account has no SHG to post the entry
  /// against, so the caller can tell that apart from a genuine success
  /// instead of showing "Entry added" for a write that never happened.
  Future<bool> addEntry({
    required String? shgId,
    required String? createdBy,
    required String entryType,
    required String description,
    required num debit,
    required num credit,
  }) async {
    if (!_live) {
      final previousBalance = _demoLastBalance(entryType);
      _locallyAdded.add(FinancialEntry(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        entryType: entryType,
        description: description,
        debit: debit,
        credit: credit,
        balance: previousBalance + credit - debit,
        date: DateTime.now(),
        createdAt: DateTime.now(),
      ));
      return true;
    }
    if (shgId == null) return false;
    // Atomic via `add_financial_ledger_entry` (see
    // supabase/migrations/0011_atomic_loan_payment_and_ledger_balance.sql)
    // — reads the previous balance and inserts the new row inside one
    // function call, serialized with a transaction-scoped advisory lock on
    // (shgId, entryType). Used to be a "select the latest balance, then
    // insert a new row with a client-computed balance" two-round-trip
    // sequence: two concurrent postings of the same entry_type (e.g. a
    // credit and a debit entered around the same time at a group meeting)
    // could both read the same stale "previous balance" and each insert a
    // row reflecting only their own entry — the running total silently
    // lost track of whichever entry didn't win the race to be the
    // most-recently-inserted row, permanently, since every later entry
    // chains forward from that wrong balance.
    try {
      await _client.rpc('add_financial_ledger_entry', params: {
        'p_shg_id': shgId,
        'p_entry_type': entryType,
        'p_description': description,
        'p_debit': debit,
        'p_credit': credit,
        'p_created_by': createdBy,
      });
    } on PostgrestException catch (e) {
      // 'PGRST202' = function not deployed yet — see recordPayment's
      // identical fallback in loan_repository.dart for why this is the
      // correct code to check (not the raw Postgres '42883').
      if (e.code != 'PGRST202') rethrow;
      final last = await _client
          .from('financial_ledger')
          .select('balance')
          .eq('shg_id', shgId)
          .eq('entry_type', entryType)
          .order('entry_date', ascending: false)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      final previousBalance = (last?['balance'] as num?) ?? 0;
      final newBalance = previousBalance + credit - debit;
      await _client.from('financial_ledger').insert({
        'shg_id': shgId,
        'entry_type': entryType,
        'description': description,
        'debit': debit,
        'credit': credit,
        'balance': newBalance,
        'created_by': ?createdBy,
      });
    }
    return true;
  }

  DateTime _parseMockDate(String s) {
    try {
      return DateFormat('dd MMM yyyy').parse(s);
    } catch (_) {
      return DateTime.now();
    }
  }

  num _demoLastBalance(String entryType) {
    final local = _locallyAdded.where((e) => e.entryType == entryType);
    if (local.isNotEmpty) return local.last.balance;
    final mockMatch = mock.financialLedgerEntries.where((e) => e.entryType == entryType);
    return mockMatch.isEmpty ? 0 : mockMatch.first.balance;
  }
}
