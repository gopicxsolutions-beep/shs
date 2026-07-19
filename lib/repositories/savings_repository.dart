import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/members.dart' as mock_members;
import '../data/savings.dart' as mock;
import '../models/savings.dart';
import '../models/types.dart';
import '../services/supabase_service.dart';

/// Backed by `public.savings_entries` when Supabase is configured; falls
/// back to the static demo data in `lib/data/savings.dart` otherwise (same
/// dual-mode pattern as [AppState] — see its doc comment).
class SavingsRepository {
  SupabaseClient get _client => SupabaseService.instance.client;
  bool get _live => SupabaseService.isConfigured;

  Future<List<SavingsEntry>> fetchForShg(String? shgId) async {
    if (!_live || shgId == null) return _mockEntries();
    final rows = await _client
        .from('savings_entries')
        .select('*, profiles(name)')
        .eq('shg_id', shgId)
        .order('entry_date', ascending: false);
    return (rows as List).map((r) => SavingsEntry.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<List<SavingsEntry>> fetchForMember(String? memberId) async {
    // Demo mode has no real per-member session, so `_mockEntries()` is
    // scoped to the requested member's own entries (resolved to a name
    // since the mock data keys on memberName, not id) rather than returning
    // everyone's — otherwise a member would see the whole SHG's savings
    // ledger as their own, and a leader opening any member's detail page
    // would see the same mixed total for every member.
    if (!_live || memberId == null) return _mockEntries().where((e) => e.memberName == _demoMemberName(memberId)).toList();
    final rows = await _client
        .from('savings_entries')
        .select('*, profiles(name)')
        .eq('member_id', memberId)
        .order('entry_date', ascending: false);
    return (rows as List).map((r) => SavingsEntry.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> addEntry({
    required String? memberId,
    required String? shgId,
    required num amount,
    required String mode,
    required String frequency,
  }) async {
    if (!_live || memberId == null || shgId == null) return;
    await _client.from('savings_entries').insert({
      'member_id': memberId,
      'shg_id': shgId,
      'amount': amount,
      'mode': mode,
      'frequency': frequency,
      'status': 'pending',
    });
  }

  Future<void> verifyEntry(String id) async {
    if (!_live) return;
    await _client.from('savings_entries').update({'status': 'verified'}).eq('id', id);
  }

  /// Live updates for the shg's ledger (leader/staff screens).
  Stream<List<SavingsEntry>> watchForShg(String shgId) {
    return _client
        .from('savings_entries')
        .stream(primaryKey: ['id'])
        .eq('shg_id', shgId)
        .order('entry_date')
        .map((rows) => rows.map(SavingsEntry.fromMap).toList());
  }

  List<MonthlyTotal> monthlyTrend(List<SavingsEntry> entries) {
    final byMonth = <String, num>{};
    for (final e in entries) {
      final key = DateFormat('yyyy-MM').format(e.date);
      byMonth[key] = (byMonth[key] ?? 0) + e.amount;
    }
    final sortedKeys = byMonth.keys.toList()..sort();
    return sortedKeys
        .map((k) => MonthlyTotal(DateFormat('MMM').format(DateFormat('yyyy-MM').parse(k)), byMonth[k]!))
        .toList();
  }

  String _demoMemberName(String? memberId) {
    if (memberId == null) return defaultUser.name;
    final match = mock_members.members.where((m) => m.id == memberId);
    return match.isEmpty ? defaultUser.name : match.first.name;
  }

  List<SavingsEntry> _mockEntries() => mock.savingsEntries
      .map((e) => SavingsEntry(
            id: e.id,
            memberId: e.id,
            memberName: e.memberName,
            date: _parseMockDate(e.date),
            amount: e.amount,
            mode: e.mode,
            frequency: e.type,
            status: e.status,
          ))
      .toList();

  DateTime _parseMockDate(String s) {
    try {
      return DateFormat('dd MMM yyyy').parse(s);
    } catch (_) {
      return DateTime.now();
    }
  }
}
