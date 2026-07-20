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
    final rows = await _client
        .from('financial_ledger')
        .select()
        .eq('shg_id', shgId)
        .eq('entry_type', entryType)
        .order('entry_date', ascending: false)
        .order('created_at', ascending: false);
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
