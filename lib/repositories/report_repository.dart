import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/meetings.dart' as mock_meetings;
import '../models/report.dart';
import '../services/supabase_service.dart';
import 'loan_repository.dart';
import 'savings_repository.dart';
import 'shg_repository.dart';
import 'trend_repository.dart';

/// `public.report_snapshots` exists so an Edge Function can eventually
/// generate these server-side and cache them (`report_snapshots_write_staff`
/// restricts writes to staff). No such function is wired yet, so this
/// repository computes the same shape on-the-fly from live tables — a
/// documented placeholder for that future server-side generation. In demo
/// mode (no Supabase configured) it returns a small illustrative snapshot
/// instead of hitting any table.
class ReportRepository {
  SupabaseClient get _client => SupabaseService.instance.client;
  bool get _live => SupabaseService.isConfigured;

  Future<MemberReport> fetchMemberReport({required String? memberId, required String? shgId}) async {
    if (!_live || memberId == null || shgId == null) {
      // Computed from the same mock data the Savings/Loans/Meetings pages
      // show, rather than a fixed snapshot, so this doesn't drift out of
      // sync with what tapping through to those pages actually displays.
      final savings = await SavingsRepository().fetchForMember(memberId);
      final loans = await LoanRepository().fetchForMember(memberId);
      final totalSavings = savings.fold<num>(0, (s, e) => s + e.amount);
      final activeLoans = loans.where((l) => l.status == 'active' || l.status == 'overdue').toList();
      final totalOutstanding = activeLoans.fold<num>(0, (s, l) => s + l.outstanding);
      // Mock meetings carry no per-member attendance, so the demo persona is
      // treated as present at every completed meeting — same assumption
      // MeetingRepository.fetchAttendanceHistory's demo branch makes.
      final completedMeetings = mock_meetings.meetings.where((m) => m.status == 'completed').length;
      return MemberReport(
        totalSavings: totalSavings,
        savingsEntryCount: savings.length,
        totalOutstanding: totalOutstanding,
        activeLoanCount: activeLoans.length,
        meetingsAttended: completedMeetings,
        meetingsTotal: completedMeetings,
        period: 'All time',
      );
    }
    final savings = await _client.from('savings_entries').select('amount').eq('member_id', memberId);
    final totalSavings = (savings as List).fold<num>(0, (s, r) => s + ((r as Map<String, dynamic>)['amount'] as num));

    final loans = await _client.from('loans').select('outstanding, status').eq('member_id', memberId);
    num totalOutstanding = 0;
    int activeLoanCount = 0;
    for (final r in loans as List) {
      final map = r as Map<String, dynamic>;
      final status = map['status'] as String;
      if (status == 'active' || status == 'overdue') {
        totalOutstanding += map['outstanding'] as num;
        activeLoanCount++;
      }
    }

    final completedMeetings = await _client.from('meetings').select('id').eq('shg_id', shgId).eq('status', 'completed');
    final meetingsTotal = (completedMeetings as List).length;
    final attendance = await _client
        .from('meeting_attendance')
        .select('present, meetings!inner(shg_id, status)')
        .eq('member_id', memberId)
        .eq('meetings.shg_id', shgId)
        .eq('meetings.status', 'completed');
    final meetingsAttended = (attendance as List).where((r) => (r as Map<String, dynamic>)['present'] == true).length;

    return MemberReport(
      totalSavings: totalSavings,
      savingsEntryCount: (savings).length,
      totalOutstanding: totalOutstanding,
      activeLoanCount: activeLoanCount,
      meetingsAttended: meetingsAttended,
      meetingsTotal: meetingsTotal,
      period: 'All time',
    );
  }

  Future<ShgReportData> fetchShgReport(String? shgId) async {
    if (!_live || shgId == null) {
      // Computed from the same mock data the Members/Savings/Loans pages
      // show, rather than a fixed snapshot, so this doesn't drift out of
      // sync with what tapping through to those pages actually displays.
      final savings = await SavingsRepository().fetchForShg(shgId);
      final loans = await LoanRepository().fetchForShg(shgId);
      final totalSavings = savings.fold<num>(0, (s, e) => s + e.amount);
      final activeLoans = loans.where((l) => l.status == 'active' || l.status == 'overdue').toList();
      final totalOutstanding = activeLoans.fold<num>(0, (s, l) => s + l.outstanding);
      final memberCount = (await ShgRepository().fetchMembers(shgId)).length;
      // Derived from the same monthly points the Performance Report's own
      // trend chart plots (TrendRepository.attendanceTrend), rather than
      // recomputed independently from the raw meeting records — two
      // separate calculations here previously drifted apart (88% headline
      // vs a ~83% trend-chart average) since they read different fields.
      final attendancePoints = await TrendRepository().attendanceTrend(shgId: shgId);
      final avgAttendancePct = attendancePoints.isEmpty
          ? 0.0
          : attendancePoints.fold<num>(0, (s, p) => s + p.value) / attendancePoints.length;
      return ShgReportData(
        memberCount: memberCount,
        totalSavings: totalSavings,
        totalOutstanding: totalOutstanding,
        activeLoanCount: activeLoans.length,
        avgAttendancePct: avgAttendancePct,
        period: 'All time',
      );
    }
    final members = await _client.from('profiles').select('id').eq('shg_id', shgId);
    final memberCount = (members as List).length;

    final savings = await _client.from('savings_entries').select('amount').eq('shg_id', shgId);
    final totalSavings = (savings as List).fold<num>(0, (s, r) => s + ((r as Map<String, dynamic>)['amount'] as num));

    final loans = await _client.from('loans').select('outstanding, status').eq('shg_id', shgId);
    num totalOutstanding = 0;
    int activeLoanCount = 0;
    for (final r in loans as List) {
      final map = r as Map<String, dynamic>;
      final status = map['status'] as String;
      if (status == 'active' || status == 'overdue') {
        totalOutstanding += map['outstanding'] as num;
        activeLoanCount++;
      }
    }

    final completedMeetings = await _client.from('meetings').select('id').eq('shg_id', shgId).eq('status', 'completed');
    final meetingsTotal = (completedMeetings as List).length;
    double avgAttendancePct = 0;
    if (meetingsTotal > 0 && memberCount > 0) {
      final attendance = await _client.from('meeting_attendance').select('present, meetings!inner(shg_id, status)').eq('meetings.shg_id', shgId).eq('meetings.status', 'completed');
      final presentCount = (attendance as List).where((r) => (r as Map<String, dynamic>)['present'] == true).length;
      avgAttendancePct = (presentCount / (meetingsTotal * memberCount)) * 100;
    }

    return ShgReportData(
      memberCount: memberCount,
      totalSavings: totalSavings,
      totalOutstanding: totalOutstanding,
      activeLoanCount: activeLoanCount,
      avgAttendancePct: avgAttendancePct,
      period: 'All time',
    );
  }

  /// Aggregates across every SHG — relies on the `is_staff()` RLS bypass on
  /// `shgs` / `savings_entries` / `loans` / `profiles`, so this only returns
  /// meaningful (non-empty) data for crp/clf/admin callers.
  Future<FederationReportData> fetchFederationReport() async {
    if (!_live) {
      return const FederationReportData(shgCount: 8, memberCount: 96, totalSavings: 4120000, totalOutstanding: 1180000, period: 'All time');
    }
    final shgs = await _client.from('shgs').select('id');
    final shgCount = (shgs as List).length;

    final members = await _client.from('profiles').select('id').eq('role', 'member');
    final memberCount = (members as List).length;

    final savings = await _client.from('savings_entries').select('amount');
    final totalSavings = (savings as List).fold<num>(0, (s, r) => s + ((r as Map<String, dynamic>)['amount'] as num));

    final loans = await _client.from('loans').select('outstanding, status');
    num totalOutstanding = 0;
    for (final r in loans as List) {
      final map = r as Map<String, dynamic>;
      final status = map['status'] as String;
      if (status == 'active' || status == 'overdue') totalOutstanding += map['outstanding'] as num;
    }

    return FederationReportData(
      shgCount: shgCount,
      memberCount: memberCount,
      totalSavings: totalSavings,
      totalOutstanding: totalOutstanding,
      period: 'All time',
    );
  }

  /// Every SHG grouped by village, with a per-village SHG count and total
  /// savings — backs the Federation "Village-wise SHGs" report.
  Future<List<VillageShgGroup>> fetchVillageWiseShgs() async {
    if (!_live) {
      return const [
        VillageShgGroup(village: 'Kondapur', shgCount: 24, totalSavings: 6100000),
        VillageShgGroup(village: 'Hanamkonda', shgCount: 31, totalSavings: 8300000),
        VillageShgGroup(village: 'Warangal Rural', shgCount: 28, totalSavings: 7200000),
        VillageShgGroup(village: 'Narsampet', shgCount: 19, totalSavings: 4600000),
        VillageShgGroup(village: 'Parkal', shgCount: 22, totalSavings: 5400000),
      ];
    }
    final shgs = await _client.from('shgs').select('id, village');
    final shgList = shgs as List;
    final villageByShgId = <String, String>{for (final r in shgList) (r as Map<String, dynamic>)['id'] as String: (r['village'] as String?) ?? 'Unknown'};

    final savings = await _client.from('savings_entries').select('shg_id, amount');
    final savingsByShg = <String, num>{};
    for (final r in savings as List) {
      final map = r as Map<String, dynamic>;
      final shgId = map['shg_id'] as String;
      savingsByShg[shgId] = (savingsByShg[shgId] ?? 0) + (map['amount'] as num);
    }

    final shgCountByVillage = <String, int>{};
    final savingsByVillage = <String, num>{};
    for (final entry in villageByShgId.entries) {
      final village = entry.value;
      shgCountByVillage[village] = (shgCountByVillage[village] ?? 0) + 1;
      savingsByVillage[village] = (savingsByVillage[village] ?? 0) + (savingsByShg[entry.key] ?? 0);
    }

    final villages = shgCountByVillage.keys.toList()..sort();
    return villages.map((v) => VillageShgGroup(village: v, shgCount: shgCountByVillage[v]!, totalSavings: savingsByVillage[v] ?? 0)).toList();
  }
}
