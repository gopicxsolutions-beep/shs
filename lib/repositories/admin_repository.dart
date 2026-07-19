import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/analytics.dart' as mock_analytics;
import '../data/members.dart' as mock;
import '../models/admin.dart';
import '../models/profile.dart';
import '../services/supabase_service.dart';

const _mockRoleMap = <String, String>{
  'President': 'leader',
  'Secretary': 'leader',
  'Treasurer': 'leader',
  'Member': 'member',
};

/// Backed by `public.profiles` (user management, admin-only writes per
/// `profiles_update_self_or_admin`) and computed table counts for system
/// monitoring (see [SystemHealth] — a documented placeholder for real
/// infra metrics). Scheme catalog CRUD lives on [SchemeRepository] since
/// it's the same table the member-facing Schemes module already reads.
class AdminRepository {
  SupabaseClient get _client => SupabaseService.instance.client;
  bool get _live => SupabaseService.isConfigured;

  // Demo mode has no backing table, so a role change would otherwise revert
  // the instant the user list reloads — track it here so it survives for
  // the rest of the session, mirroring AnnouncementRepository._locallyRead.
  static final Map<String, String> _locallyUpdatedRoles = {};

  Future<List<Profile>> fetchAllUsers() async {
    if (!_live) {
      return mock.members
          .map((m) => Profile(id: m.id, name: m.name, mobile: m.mobile, role: _locallyUpdatedRoles[m.id] ?? _mockRoleMap[m.role] ?? 'member', shgId: 'demo-shg', village: null))
          .toList();
    }
    final rows = await _client.from('profiles').select().order('name');
    return (rows as List).map((r) => Profile.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> updateUserRole(String userId, String role) async {
    if (!_live) {
      _locallyUpdatedRoles[userId] = role;
      return;
    }
    await _client.from('profiles').update({'role': role}).eq('id', userId);
  }

  Future<SystemHealth> fetchSystemHealth() async {
    if (!_live) {
      // totalUsers/totalShgs mirror the same platform-wide figures the
      // Admin dashboard shows (Kpis.activeMembers, the village breakdown's
      // SHG count) rather than this demo persona's own single-SHG roster
      // (12 members, 1 SHG) — that mismatch (2142 vs 12, 124 vs 1) made
      // System Monitoring directly contradict the dashboard one tap away.
      final totalShgs = mock_analytics.villageWiseSHGs.fold<int>(0, (s, v) => s + v.shgs);
      return SystemHealth(totalUsers: mock_analytics.Kpis.activeMembers, totalShgs: totalShgs, totalSavingsEntries: 48, totalLoans: 6, pendingLoans: 1, checkedAt: DateTime.now());
    }
    final users = await _client.from('profiles').select('id');
    final shgs = await _client.from('shgs').select('id');
    final savings = await _client.from('savings_entries').select('id');
    final loans = await _client.from('loans').select('id, status');
    final pendingLoans = (loans as List).where((r) => (r as Map<String, dynamic>)['status'] == 'pending').length;
    return SystemHealth(
      totalUsers: (users as List).length,
      totalShgs: (shgs as List).length,
      totalSavingsEntries: (savings as List).length,
      totalLoans: loans.length,
      pendingLoans: pendingLoans,
      checkedAt: DateTime.now(),
    );
  }
}
