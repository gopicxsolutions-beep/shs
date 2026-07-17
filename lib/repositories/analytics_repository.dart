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
      return const PlatformKpis(
        totalShgs: mock.Kpis.totalSHGs,
        activeMembers: mock.Kpis.activeMembers,
        totalSavings: mock.Kpis.totalSavings,
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
    final results = <ShgHealth>[];
    for (final r in shgs as List) {
      final map = r as Map<String, dynamic>;
      final id = map['id'] as String;
      final report = await _reportRepo.fetchShgReport(id);
      results.add(ShgHealth(
        id: id,
        name: map['name'] as String,
        village: map['village'] as String? ?? '',
        grade: map['grade'] as String?,
        memberCount: report.memberCount,
        totalSavings: report.totalSavings,
        healthScore: report.avgAttendancePct,
      ));
    }
    return results;
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
