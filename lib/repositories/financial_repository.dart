import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/financial.dart' as mock;
import '../models/financial_entry.dart';
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

  Future<List<FinancialEntry>> fetchForShg(String? shgId, String entryType) async {
    if (!_live) {
      final mockEntries = mock.financialLedgerEntries
          .where((e) => e.entryType == entryType)
          .map((e) => FinancialEntry(id: e.id, entryType: e.entryType, description: e.description, debit: e.debit, credit: e.credit, balance: e.balance, date: _parseMockDate(e.date)));
      final localEntries = _locallyAdded.where((e) => e.entryType == entryType).toList().reversed;
      return [...localEntries, ...mockEntries];
    }
    if (shgId == null) return [];
    // One SHG's cashbook/ledger/bank/audit history accumulates indefinitely
    // over the group's lifetime (years of meetings, each potentially adding
    // entries) — previously had no `.limit()` at all. Safe to cap here
    // (unlike SavingsRepository.fetchForMember, deliberately left uncapped
    // after this session already caught and reverted that exact mistake —
    // see docs/DEVELOPMENT_PROGRESS.md round 65): FinancialLedgerPage
    // displays each row's own already-computed `balance` field rather than
    // summing the fetched list client-side, so truncating the query cannot
    // produce a wrong total. Capped at a generous 500; newest-first
    // ordering means only very old entries (year+ history for a
    // long-running SHG) would ever fall past the cap.
    final rows = await _client
        .from('financial_ledger')
        .select()
        .eq('shg_id', shgId)
        .eq('entry_type', entryType)
        .order('entry_date', ascending: false)
        .order('created_at', ascending: false)
        .limit(500);
    return (rows as List).map((r) => FinancialEntry.fromMap(r as Map<String, dynamic>)).toList();
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
