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

  // Test-only seam (null by default, so every existing test keeps seeing
  // the exact short mock.members it always has).
  // test/routes/long_content_stress_test.dart sets this (in lockstep with
  // ShgRepository.debugMembersOverride, which it mirrors — kept as a
  // separate field rather than a shared import to avoid a new cross-
  // repository dependency existing only for this test seam) to exercise a
  // realistic long member name at a normal viewport, then resets it — no
  // change to lib/data/members.dart's shared mock records themselves.
  static List<mock.Member>? debugMembersOverride;

  /// Lets [ShgRepository]'s demo branch (fetchMembers/fetchMember) reflect
  /// a role change made here via Manage Users — otherwise an admin
  /// promoting/demoting a member in this repository's own local store
  /// never showed up in that member's own "My SHG" roster or profile badge
  /// for the rest of the "Preview as" session, one role's view silently
  /// disagreeing with another's for the same underlying member.
  static String roleOverride(String userId, String fallback) => _locallyUpdatedRoles[userId] ?? fallback;

  Future<List<Profile>> fetchAllUsers() async {
    if (!_live) {
      return (debugMembersOverride ?? mock.members)
          .map((m) => Profile(id: m.id, name: m.name, mobile: m.mobile, role: _locallyUpdatedRoles[m.id] ?? _mockRoleMap[m.role] ?? 'member', shgId: _locallyAssignedShgs[m.id] ?? 'demo-shg', village: null))
          .toList();
    }
    // Every user on the platform, not scoped to any one SHG — AdminUsersPage
    // has no search/filter to narrow this. Previously had no `.limit()` at
    // all. Capped at a generous 500 rather than left fully unbounded (same
    // defensive cap as the other platform-wide admin/catalog queries), but
    // unlike those, this list is ordered alphabetically rather than by
    // recency, so a real deployment growing past 500 users would have the
    // cutoff hide an arbitrary alphabetical tail with no way to reach them
    // from this page — a real gap, but fixing it properly needs actual
    // search/pagination on AdminUsersPage, which is out of scope for this
    // minimal cap.
    final rows = await _client.from('profiles').select().order('name').limit(500);
    return (rows as List).map((r) => Profile.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> updateUserRole(String userId, String role) async {
    if (!_live) {
      _locallyUpdatedRoles[userId] = role;
      return;
    }
    await _client.from('profiles').update({'role': role}).eq('id', userId);
  }

  // Same demo-mode local-tracking shape as _locallyUpdatedRoles, above.
  static final Map<String, String> _locallyAssignedShgs = {};

  Future<void> assignShg(String userId, String shgId) async {
    if (!_live) {
      _locallyAssignedShgs[userId] = shgId;
      return;
    }
    await _client.from('profiles').update({'shg_id': shgId}).eq('id', userId);
  }

  Future<List<ShgSearchResult>> searchShgs(String query) async {
    if (!_live) return const [];
    final builder = _client.from('shg_directory').select();
    final rows = await (query.trim().isEmpty ? builder.limit(20) : builder.ilike('name', '%${query.trim()}%').limit(20));
    return (rows as List).map((r) => ShgSearchResult.fromMap(r as Map<String, dynamic>)).toList();
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
