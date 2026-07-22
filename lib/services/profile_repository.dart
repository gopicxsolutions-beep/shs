import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';
import 'supabase_service.dart';

class ProfileRepository {
  SupabaseClient get _client => SupabaseService.instance.client;

  Future<Profile?> fetchMyProfile() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await _client.from('profiles').select().eq('id', uid).maybeSingle();
    if (row == null) return null;
    return Profile.fromMap(row);
  }

  Future<Profile> upsertMyProfile({
    required String name,
    String? mobile,
    String role = 'member',
    String? shgId,
    String? village,
  }) async {
    final uid = _client.auth.currentUser!.id;
    final row = await _client
        .from('profiles')
        .upsert({
          'id': uid,
          'name': name,
          'mobile': ?mobile,
          'role': role,
          'shg_id': ?shgId,
          'village': ?village,
        })
        .select()
        .single();
    return Profile.fromMap(row);
  }

  Future<void> updateRole(String role) async {
    final uid = _client.auth.currentUser!.id;
    await _client.from('profiles').update({'role': role}).eq('id', uid);
  }

  // A plain UPDATE, not `upsertMyProfile`'s upsert. For `INSERT ... ON
  // CONFLICT DO UPDATE`, Postgres enforces the INSERT policy's WITH CHECK
  // against the proposed row even when the conflict path is taken — so
  // upserting an edit for an existing crp/clf/admin profile would fail
  // `profiles_insert_self`'s `role in ('member', 'leader')` check
  // (0022_profiles_insert_self_privilege_escalation_fix.sql), which is
  // correctly scoped to first-time self-service signup, not edits to an
  // already-existing profile of any role.
  Future<Profile> updateNameVillage({required String name, String? village}) async {
    final uid = _client.auth.currentUser!.id;
    final row = await _client.from('profiles').update({'name': name, 'village': ?village}).eq('id', uid).select().single();
    return Profile.fromMap(row);
  }

  Future<List<ShgSearchResult>> searchShgs(String query) async {
    final builder = _client.from('shg_directory').select();
    final rows = await (query.trim().isEmpty ? builder.limit(20) : builder.ilike('name', '%${query.trim()}%').limit(20));
    return (rows as List).map((r) => ShgSearchResult.fromMap(r as Map<String, dynamic>)).toList();
  }
}
