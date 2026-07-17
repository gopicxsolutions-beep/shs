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

  Future<List<FinancialEntry>> fetchForShg(String? shgId, String entryType) async {
    if (!_live || shgId == null) {
      return mock.financialLedgerEntries
          .where((e) => e.entryType == entryType)
          .map((e) => FinancialEntry(id: e.id, entryType: e.entryType, description: e.description, debit: e.debit, credit: e.credit, balance: e.balance, date: _parseMockDate(e.date)))
          .toList();
    }
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
  Future<void> addEntry({
    required String? shgId,
    required String? createdBy,
    required String entryType,
    required String description,
    required num debit,
    required num credit,
  }) async {
    if (!_live || shgId == null) return;
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
      if (createdBy != null) 'created_by': createdBy,
    });
  }

  DateTime _parseMockDate(String s) {
    try {
      return DateFormat('dd MMM yyyy').parse(s);
    } catch (_) {
      return DateTime.now();
    }
  }
}
