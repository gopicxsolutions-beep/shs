import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trend.dart';
import '../services/supabase_service.dart';
import 'meeting_repository.dart';

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
    // Only verified entries — a pending entry is an unconfirmed self-report,
    // not yet reconciled by an SHG leader (same reasoning as ReportRepository/
    // AnalyticsRepository's totals, kept consistent with this trend chart).
    var query = _client.from('savings_entries').select('amount, entry_date').eq('status', 'verified');
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
    if (!_live) return _mockAttendanceTrend(shgId);
    // `status = 'completed'` never actually matches in live mode —
    // `MeetingRepository.setStatus()` is only ever called to set
    // 'cancelled' (see its doc comment), never 'completed', so a real
    // meeting's status stays 'upcoming' forever on its own. Use the
    // meeting's own date instead, the same fix already applied in
    // `MeetingRepository.fetchAttendanceHistory()` and `ReportRepository`'s
    // attendance queries — without this, the Performance Report's
    // "Attendance Trend" chart was permanently stuck showing "No completed
    // meetings yet" for every SHG. `.neq('status', 'cancelled')` still
    // excludes a meeting cancelled after its date passed, so it doesn't
    // drag a month's attendance rate down as a 0%-attended completed
    // meeting.
    final todayStr = DateTime.now().toIso8601String().split('T').first;
    var meetingsQuery = _client.from('meetings').select('id, meeting_date').neq('status', 'cancelled').lt('meeting_date', todayStr);
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
    return _lastSixMonthKeys().map((k) {
      final (present, total) = byMonth[k] ?? (0, 0);
      final pct = total == 0 ? 0.0 : (present / total) * 100;
      return MonthlyPoint(DateFormat('MMM').format(DateFormat('yyyy-MM').parse(k)), pct);
    }).toList();
  }

  /// Demo-mode `attendanceTrend`, computed from `MeetingRepository`'s own
  /// mock/session-local state instead of a fixed illustrative array. Before
  /// this fix, the hardcoded array ignored [shgId] entirely and never
  /// consulted `MeetingRepository` at all — so cancelling a meeting via
  /// `MeetingDetailPage`'s "Cancel Meeting" action changed `ReportRepository.
  /// fetchMemberReport`'s demo-mode `meetingsTotal` (which correctly reads
  /// through `MeetingRepository.fetchForShg`) but left this method's output —
  /// and therefore `ReportRepository.fetchShgReport`'s `avgAttendancePct`,
  /// which derives from exactly this method (see its own doc comment) —
  /// completely unchanged. A leader cancelling a meeting in demo mode would
  /// see the Member Report's attendance count drop while the SHG Performance
  /// Report / CRP SHG Health screens kept showing the pre-cancellation
  /// number, disagreeing with each other in the same session.
  ///
  /// Mirrors `ReportRepository.fetchMemberReport`'s own demo branch: only
  /// `status == 'completed'` meetings count (a cancelled meeting — whether
  /// cancelled via the static mock data or this session's `_locallyCancelled`
  /// overlay — is excluded, same as an 'upcoming' one that hasn't happened
  /// yet), and attendance per meeting comes from `fetchAttendance`'s own
  /// `_locallyMarked` overlay (present-by-default, exactly like
  /// `fetchAttendanceHistory`'s demo branch assumes), so a leader's manual
  /// attendance edits are reflected here too, not just cancellations.
  Future<List<MonthlyPoint>> _mockAttendanceTrend(String? shgId) async {
    final meetingRepo = MeetingRepository();
    final completedMeetings = (await meetingRepo.fetchForShg(shgId)).where((m) => m.status == 'completed');
    final byMonth = <String, (int present, int total)>{};
    for (final m in completedMeetings) {
      final roster = await meetingRepo.fetchAttendance(m.id, shgId);
      if (roster.isEmpty) continue;
      final present = roster.where((r) => r.present).length;
      final key = DateFormat('yyyy-MM').format(m.date);
      final current = byMonth[key] ?? (0, 0);
      byMonth[key] = (current.$1 + present, current.$2 + roster.length);
    }
    return _lastSixMonthKeys().map((k) {
      final (present, total) = byMonth[k] ?? (0, 0);
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
    return _lastSixMonthKeys().map((k) => MonthlyPoint(DateFormat('MMM').format(DateFormat('yyyy-MM').parse(k)), byMonth[k] ?? 0)).toList();
  }

  /// The 6 calendar months ending this month, anchored to the real current
  /// date — NOT just "whichever 6 months happen to have data". The previous
  /// version sorted and sliced `byMonth.keys`, so a gap in recent data (e.g.
  /// this month's entries not recorded yet) silently dropped the current
  /// month from the chart instead of showing it as 0, and an SHG whose most
  /// recent activity was over a year old would have its stale months
  /// mislabeled as if they were the current 6-month window (only "MMM", no
  /// year, is ever shown on the chart axis).
  List<String> _lastSixMonthKeys() {
    final now = DateTime.now();
    return [for (var i = 5; i >= 0; i--) DateFormat('yyyy-MM').format(DateTime(now.year, now.month - i))];
  }

  List<MonthlyPoint> _mockTrend(List<num> values) {
    const months = ['Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul'];
    return [for (var i = 0; i < values.length; i++) MonthlyPoint(months[i], values[i])];
  }
}
