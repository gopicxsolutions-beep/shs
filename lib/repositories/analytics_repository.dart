import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/analytics.dart' as mock;
import '../models/analytics.dart';
import '../services/supabase_service.dart';
import 'report_repository.dart';

/// `public.analytics_kpis` exists for an Edge Function to eventually
/// populate (`analytics_kpis_write_staff` restricts writes to staff), same
/// story as `report_snapshots` in [ReportRepository]. Until that exists,
/// this repository computes the same shape on-the-fly — platform KPIs
/// aggregate across every SHG (relies on the `is_staff()` RLS bypass, so
/// only meaningful for crp/clf/admin callers), and per-SHG health reuses
/// [ReportRepository.fetchShgReport]'s attendance figure as a real,
/// defensible proxy metric.
class AnalyticsRepository {
  SupabaseClient get _client => SupabaseService.instance.client;
  bool get _live => SupabaseService.isConfigured;
  final ReportRepository _reportRepo = ReportRepository();

  Future<PlatformKpis> fetchPlatformKpis() async {
    if (!_live) {
      // totalShgs/totalSavings are derived from the same village breakdown
      // shown on the Federation "Village-wise SHGs" report, rather than the
      // separate Kpis.totalSHGs/totalSavings constants — those had drifted
      // out of sync (186 SHGs / ₹4.86Cr vs. the villages' actual 124 / ₹3.16Cr),
      // so the CLF/Admin dashboard summary contradicted its own drill-down.
      final totalShgs = mock.villageWiseSHGs.fold<int>(0, (s, v) => s + v.shgs);
      final totalSavings = mock.villageWiseSHGs.fold<int>(0, (s, v) => s + v.savings);
      return PlatformKpis(
        totalShgs: totalShgs,
        activeMembers: mock.Kpis.activeMembers,
        totalSavings: totalSavings,
        loansDisbursed: mock.Kpis.loansDisbursed,
        recoveryRatePct: mock.Kpis.recoveryRate,
      );
    }
    final shgs = await _client.from('shgs').select('id');
    final totalShgs = (shgs as List).length;

    final members = await _client.from('profiles').select('id').eq('role', 'member');
    final activeMembers = (members as List).length;

    // Only verified entries count as real group funds — a pending entry is
    // an unconfirmed self-report, not yet reconciled by an SHG leader.
    final savings = await _client.from('savings_entries').select('amount').eq('status', 'verified');
    final totalSavings = (savings as List).fold<num>(0, (s, r) => s + ((r as Map<String, dynamic>)['amount'] as num));

    final loans = await _client.from('loans').select('amount, outstanding, status');
    num disbursed = 0;
    num repaid = 0;
    for (final r in loans as List) {
      final map = r as Map<String, dynamic>;
      final status = map['status'] as String;
      if (status == 'active' || status == 'overdue' || status == 'closed') {
        final amount = map['amount'] as num;
        final outstanding = map['outstanding'] as num;
        disbursed += amount;
        repaid += (amount - outstanding);
      }
    }
    final recoveryRatePct = disbursed == 0 ? 0.0 : (repaid / disbursed) * 100;

    return PlatformKpis(
      totalShgs: totalShgs,
      activeMembers: activeMembers,
      totalSavings: totalSavings,
      loansDisbursed: disbursed,
      recoveryRatePct: recoveryRatePct,
    );
  }

  /// Was `Future.wait(shgs.map((s) => _reportRepo.fetchShgReport(s.id)))` —
  /// one 5-query round trip *per SHG* (members, savings, loans, meetings,
  /// attendance), i.e. 1 + 5N queries for N SHGs. For a real federation
  /// (this is the CRP dashboard's landing-screen data, loaded on every
  /// login) that's 150+ queries for 30 SHGs on one screen. `ShgHealth` only
  /// needs memberCount/totalSavings/healthScore (no loan figures), so this
  /// batches those 3 metrics across every SHG in one query each — a
  /// constant ~4 queries total regardless of SHG count — and groups the
  /// results client-side by `shg_id`, computing the same
  /// present/(meetings×members) attendance formula ReportRepository.fetchShgReport
  /// uses for a single SHG.
  Future<List<ShgHealth>> fetchShgList() async {
    if (!_live) {
      return mock.shgsForMonitoring.map((g) => ShgHealth(id: g.id, name: g.name, village: g.village, grade: g.grade, memberCount: g.members, totalSavings: g.savings, healthScore: g.health.toDouble())).toList();
    }
    final shgs = await _client.from('shgs').select('id, name, village, grade').order('name');
    final shgRows = (shgs as List).cast<Map<String, dynamic>>();
    final shgIds = shgRows.map((r) => r['id'] as String).toList();
    if (shgIds.isEmpty) return const [];

    final memberCountByShg = <String, int>{};
    final members = await _client.from('profiles').select('shg_id').inFilter('shg_id', shgIds);
    for (final r in members as List) {
      final shgId = (r as Map<String, dynamic>)['shg_id'] as String;
      memberCountByShg[shgId] = (memberCountByShg[shgId] ?? 0) + 1;
    }

    final savingsByShg = <String, num>{};
    final savings = await _client.from('savings_entries').select('shg_id, amount').inFilter('shg_id', shgIds).eq('status', 'verified');
    for (final r in savings as List) {
      final map = r as Map<String, dynamic>;
      final shgId = map['shg_id'] as String;
      savingsByShg[shgId] = (savingsByShg[shgId] ?? 0) + (map['amount'] as num);
    }

    // `status = 'completed'` never actually matches in live mode — nothing
    // in the app ever calls `MeetingRepository.setStatus()` (see
    // `Meeting.hasPassed`'s doc comment), so a real meeting's status stays
    // 'upcoming' forever. Use the meeting's own date instead, the same fix
    // already applied in `MeetingRepository.fetchAttendanceHistory()` and
    // `ReportRepository`'s attendance queries — without this, every SHG's
    // `healthScore` here (and the CRP dashboard's "Avg. Health Score" stat)
    // was permanently stuck at 0%.
    final todayStr = DateTime.now().toIso8601String().split('T').first;
    final completedMeetings = await _client.from('meetings').select('id, shg_id').inFilter('shg_id', shgIds).neq('status', 'cancelled').lt('meeting_date', todayStr);
    final meetingRows = (completedMeetings as List).cast<Map<String, dynamic>>();
    final meetingsTotalByShg = <String, int>{};
    final shgByMeetingId = <String, String>{};
    for (final m in meetingRows) {
      final shgId = m['shg_id'] as String;
      meetingsTotalByShg[shgId] = (meetingsTotalByShg[shgId] ?? 0) + 1;
      shgByMeetingId[m['id'] as String] = shgId;
    }
    final presentByShg = <String, int>{};
    if (meetingRows.isNotEmpty) {
      final attendance = await _client.from('meeting_attendance').select('present, meeting_id').inFilter('meeting_id', shgByMeetingId.keys.toList()).eq('present', true);
      for (final r in attendance as List) {
        final shgId = shgByMeetingId[(r as Map<String, dynamic>)['meeting_id'] as String];
        if (shgId != null) presentByShg[shgId] = (presentByShg[shgId] ?? 0) + 1;
      }
    }

    return [
      for (final row in shgRows)
        () {
          final id = row['id'] as String;
          final memberCount = memberCountByShg[id] ?? 0;
          final meetingsTotal = meetingsTotalByShg[id] ?? 0;
          final healthScore = (meetingsTotal > 0 && memberCount > 0) ? ((presentByShg[id] ?? 0) / (meetingsTotal * memberCount)) * 100 : 0.0;
          return ShgHealth(
            id: id,
            name: row['name'] as String,
            village: row['village'] as String? ?? '',
            grade: row['grade'] as String?,
            memberCount: memberCount,
            totalSavings: savingsByShg[id] ?? 0,
            healthScore: healthScore,
          );
        }(),
    ];
  }

  Future<ShgHealth?> fetchShgDetail(String shgId) async {
    if (!_live) {
      final matches = mock.shgsForMonitoring.where((g) => g.id == shgId);
      if (matches.isEmpty) return null;
      final g = matches.first;
      return ShgHealth(id: g.id, name: g.name, village: g.village, grade: g.grade, memberCount: g.members, totalSavings: g.savings, healthScore: g.health.toDouble());
    }
    final row = await _client.from('shgs').select('id, name, village, grade').eq('id', shgId).maybeSingle();
    if (row == null) return null;
    final report = await _reportRepo.fetchShgReport(shgId);
    return ShgHealth(
      id: row['id'] as String,
      name: row['name'] as String,
      village: row['village'] as String? ?? '',
      grade: row['grade'] as String?,
      memberCount: report.memberCount,
      totalSavings: report.totalSavings,
      healthScore: report.avgAttendancePct,
    );
  }
}
