import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trend.dart';
import '../services/supabase_service.dart';

/// Computes monthly trend series (last 6 months) for the Analytics
/// dashboard's charts and the Federation "Savings Growth" report — reused
/// by both rather than duplicated. Always computed client-side from live
/// tables, same documented placeholder story as `ReportRepository` /
/// `AnalyticsRepository` (an eventual Edge Function could cache these into
/// `report_snapshots`/`analytics_kpis` instead).
class TrendRepository {
  SupabaseClient get _client => SupabaseService.instance.client;
  bool get _live => SupabaseService.isConfigured;

  /// [shgId] scopes to one SHG; null means federation-wide (every SHG).
  Future<List<MonthlyPoint>> savingsTrend({String? shgId}) async {
    if (!_live) return _mockTrend(const [32000, 41000, 38000, 46000, 50000, 48000]);
    var query = _client.from('savings_entries').select('amount, entry_date');
    final rows = shgId != null ? await query.eq('shg_id', shgId) : await query;
    return _bucketByMonth(rows as List, dateKey: 'entry_date', valueKey: 'amount');
  }

  Future<List<MonthlyPoint>> loanTrend({String? shgId}) async {
    if (!_live) return _mockTrend(const [15000, 22000, 18000, 26000, 30000, 24000]);
    var query = _client.from('loans').select('amount, created_at').inFilter('status', ['active', 'overdue', 'closed']);
    final rows = shgId != null ? await query.eq('shg_id', shgId) : await query;
    return _bucketByMonth(rows as List, dateKey: 'created_at', valueKey: 'amount');
  }

  /// Federation-wide only — Marketplace orders aren't scoped to a single
  /// SHG in the schema (they're linked via `marketplace_products`), and
  /// the only caller (Analytics) is a staff-only, platform-wide view.
  Future<List<MonthlyPoint>> revenueTrend() async {
    if (!_live) return _mockTrend(const [8000, 12000, 9500, 14000, 16000, 13000]);
    final rows = await _client.from('marketplace_orders').select('amount, order_date');
    return _bucketByMonth(rows as List, dateKey: 'order_date', valueKey: 'amount');
  }

  /// Attendance rate per month = present rows / total attendance rows
  /// recorded that month, restricted to completed meetings.
  Future<List<MonthlyPoint>> attendanceTrend({String? shgId}) async {
    if (!_live) return _mockTrend(const [78, 82, 75, 88, 91, 85]);
    var meetingsQuery = _client.from('meetings').select('id, meeting_date').eq('status', 'completed');
    final meetings = (shgId != null ? await meetingsQuery.eq('shg_id', shgId) : await meetingsQuery) as List;
    if (meetings.isEmpty) return const [];
    final meetingDates = {for (final m in meetings) m['id'] as String: m['meeting_date'] as String};
    final meetingIds = meetingDates.keys.toList();
    final attendance = await _client.from('meeting_attendance').select('meeting_id, present').inFilter('meeting_id', meetingIds);

    final byMonth = <String, (int present, int total)>{};
    for (final r in attendance as List) {
      final map = r as Map<String, dynamic>;
      final meetingDate = meetingDates[map['meeting_id'] as String];
      if (meetingDate == null) continue;
      final key = DateFormat('yyyy-MM').format(DateTime.parse(meetingDate));
      final current = byMonth[key] ?? (0, 0);
      final present = map['present'] == true;
      byMonth[key] = (current.$1 + (present ? 1 : 0), current.$2 + 1);
    }
    final sortedKeys = byMonth.keys.toList()..sort();
    return sortedKeys.map((k) {
      final (present, total) = byMonth[k]!;
      final pct = total == 0 ? 0.0 : (present / total) * 100;
      return MonthlyPoint(DateFormat('MMM').format(DateFormat('yyyy-MM').parse(k)), pct);
    }).toList();
  }

  List<MonthlyPoint> _bucketByMonth(List rows, {required String dateKey, required String valueKey}) {
    final byMonth = <String, num>{};
    for (final r in rows) {
      final map = r as Map<String, dynamic>;
      final dateStr = map[dateKey] as String?;
      if (dateStr == null) continue;
      final key = DateFormat('yyyy-MM').format(DateTime.parse(dateStr));
      byMonth[key] = (byMonth[key] ?? 0) + (map[valueKey] as num);
    }
    final sortedKeys = byMonth.keys.toList()..sort();
    return sortedKeys.map((k) => MonthlyPoint(DateFormat('MMM').format(DateFormat('yyyy-MM').parse(k)), byMonth[k]!)).toList();
  }

  List<MonthlyPoint> _mockTrend(List<num> values) {
    const months = ['Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul'];
    return [for (var i = 0; i < values.length; i++) MonthlyPoint(months[i], values[i])];
  }
}
