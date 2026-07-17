import 'package:supabase_flutter/supabase_flutter.dart';
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

  Future<List<Profile>> fetchAllUsers() async {
    if (!_live) {
      return mock.members
          .map((m) => Profile(id: m.id, name: m.name, mobile: m.mobile, role: _mockRoleMap[m.role] ?? 'member', shgId: 'demo-shg', village: null))
          .toList();
    }
    final rows = await _client.from('profiles').select().order('name');
    return (rows as List).map((r) => Profile.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> updateUserRole(String userId, String role) async {
    if (!_live) return;
    await _client.from('profiles').update({'role': role}).eq('id', userId);
  }

  Future<SystemHealth> fetchSystemHealth() async {
    if (!_live) {
      return SystemHealth(totalUsers: mock.members.length, totalShgs: 1, totalSavingsEntries: 48, totalLoans: 6, pendingLoans: 1, checkedAt: DateTime.now());
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
