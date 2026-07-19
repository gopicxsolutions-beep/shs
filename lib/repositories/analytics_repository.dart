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

    final savings = await _client.from('savings_entries').select('amount');
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

  Future<List<ShgHealth>> fetchShgList() async {
    if (!_live) {
      return mock.shgsForMonitoring.map((g) => ShgHealth(id: g.id, name: g.name, village: g.village, grade: g.grade, memberCount: g.members, totalSavings: g.savings, healthScore: g.health.toDouble())).toList();
    }
    final shgs = await _client.from('shgs').select('id, name, village, grade').order('name');
    final rows = (shgs as List).cast<Map<String, dynamic>>();
    final reports = await Future.wait(rows.map((map) => _reportRepo.fetchShgReport(map['id'] as String)));
    return [
      for (var i = 0; i < rows.length; i++)
        ShgHealth(
          id: rows[i]['id'] as String,
          name: rows[i]['name'] as String,
          village: rows[i]['village'] as String? ?? '',
          grade: rows[i]['grade'] as String?,
          memberCount: reports[i].memberCount,
          totalSavings: reports[i].totalSavings,
          healthScore: reports[i].avgAttendancePct,
        ),
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
