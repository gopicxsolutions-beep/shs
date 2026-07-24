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

  // Demo mode has no backing table, so a submitted entry would otherwise
  // vanish the instant the ledger reloads — track it here so it survives
  // for the rest of the session, mirroring AnnouncementRepository._locallyRead.
  static final List<SavingsEntry> _locallyAdded = [];

  /// Pure per-member totals for `SavingsGroupReportPage`'s leaderboard,
  /// factored out so it's directly unit-testable without a live DB (mirrors
  /// `AdminRepository.trainingCompletionPctFrom`'s own precedent for pulling
  /// pure arithmetic out of a page's `build()`). Keyed by **memberId**, not
  /// memberName — `profiles.name` has no uniqueness constraint, so two
  /// members sharing a display name (realistic in a village context, no
  /// dedup enforced anywhere at signup) would otherwise have their verified
  /// savings silently folded into a single combined leaderboard row, with a
  /// wrong rank for every other member too. Callers wanting a display name
  /// should build their own `memberId -> memberName` map alongside this from
  /// the same entry list (see `SavingsGroupReportPage`).
  static Map<String, num> aggregateVerifiedTotals(List<SavingsEntry> verifiedEntries) {
    final totals = <String, num>{};
    for (final e in verifiedEntries) {
      totals[e.memberId] = (totals[e.memberId] ?? 0) + e.amount;
    }
    return totals;
  }

  Future<List<SavingsEntry>> fetchForShg(String? shgId) async {
    if (!_live) return [..._locallyAdded.reversed, ..._mockEntries()];
    if (shgId == null) return [];
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
    if (!_live) {
      final name = _demoMemberName(memberId);
      return [
        ..._locallyAdded.where((e) => e.memberName == name).toList().reversed,
        ..._mockEntries().where((e) => e.memberName == name),
      ];
    }
    if (memberId == null) return [];
    final rows = await _client
        .from('savings_entries')
        .select('*, profiles(name)')
        .eq('member_id', memberId)
        .order('entry_date', ascending: false);
    return (rows as List).map((r) => SavingsEntry.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Returns whether the entry was actually saved — `false` (not an
  /// exception) when the submitting member/staff has no SHG, so the
  /// caller can tell that apart from a genuine success instead of showing
  /// "submitted for verification" for a write that never happened.
  Future<bool> addEntry({
    required String? memberId,
    required String? shgId,
    required num amount,
    required String mode,
    required String frequency,
  }) async {
    if (!_live) {
      _locallyAdded.add(SavingsEntry(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        memberId: memberId ?? 'me',
        memberName: _demoMemberName(memberId),
        date: DateTime.now(),
        amount: amount,
        mode: mode,
        frequency: frequency,
        status: 'pending',
      ));
      return true;
    }
    if (memberId == null || shgId == null) return false;
    await _client.from('savings_entries').insert({
      'member_id': memberId,
      'shg_id': shgId,
      'amount': amount,
      'mode': mode,
      'frequency': frequency,
      'status': 'pending',
    });
    return true;
  }

  Future<void> verifyEntry(String id) async {
    if (!_live) return;
    await _client.from('savings_entries').update({'status': 'verified'}).eq('id', id);
  }

  /// Live updates for the shg's ledger (leader/staff screens). Ordered
  /// newest-first to match `fetchForShg` (the demo-mode fallback used on
  /// the same page) — this used to omit `ascending: false`, so the
  /// realtime stream sorted oldest-first: a leader opening the live ledger
  /// to verify an entry a member had just submitted had to scroll past
  /// every older entry to reach it at the very bottom of the list, while
  /// the demo-mode view of the identical page showed new entries at the
  /// top as expected.
  Stream<List<SavingsEntry>> watchForShg(String shgId) {
    return _client
        .from('savings_entries')
        .stream(primaryKey: ['id'])
        .eq('shg_id', shgId)
        .order('entry_date', ascending: false)
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
