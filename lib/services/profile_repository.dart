import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';
import 'supabase_service.dart';

class ProfileRepository {
  SupabaseClient get _client => SupabaseService.instance.client;

  // [uid] is caller-resolved (from `AppState._session?.user.id`), not
  // re-derived here from `_client.auth.currentUser` — this repository's own
  // established convention (see e.g. `ShgRepository.fetchMembers(shgId)`),
  // and the reason this specific method is the fix for a real reported bug:
  // an already-registered member relogging in (or resuming the app after a
  // while) was sometimes asked to redo the ENTIRE onboarding wizard — basic
  // info AND the baseline survey — with no error shown at all. Root cause:
  // `_client.auth.currentUser` is the underlying Supabase client's OWN
  // internal field, populated by its auth listener asynchronously — it is
  // not guaranteed to already reflect the session at every moment
  // `_loadProfile()` runs (app-resume, a background token refresh still
  // settling, …). When it was transiently null, this method returned `null`
  // WITHOUT throwing — indistinguishable from "no profile row exists yet" —
  // and `AppState._loadProfile()` treated that as a **confirmed** empty
  // result, overwriting an already-loaded `_profile` and sending a genuine
  // returning member straight back into the full wizard. `AppState._session`
  // is set directly from the auth event/session object itself (the same
  // source `completeProfileSetup`'s `mobile: _session?.user.phone` already
  // reads from), not from this separate, independently-timed client field.
  Future<Profile?> fetchMyProfile(String? uid) async {
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
    String? mandal,
    String? district,
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
          'mandal': ?mandal,
          'district': ?district,
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
  // Unlike `village`'s `?village` (present-but-unset-means-"don't touch"),
  // `mandal`/`district` are always sent as a real value, including `null` —
  // a user clearing one of these fields to correct a mistaken entry must
  // actually clear the stored value too, not silently leave the old one in
  // place.
  Future<Profile> updateProfile({required String name, String? village, String? mandal, String? district}) async {
    final uid = _client.auth.currentUser!.id;
    final row = await _client.from('profiles').update({'name': name, 'village': ?village, 'mandal': mandal, 'district': district}).eq('id', uid).select().single();
    return Profile.fromMap(row);
  }

  Future<List<ShgSearchResult>> searchShgs(String query) async {
    final builder = _client.from('shg_directory').select();
    // Without an explicit order, PostgREST doesn't guarantee row order —
    // results could shuffle between an empty-query browse and a re-search,
    // unlike ShgRepository.fetchAllShgs's own `.order('name')`.
    final rows = await (query.trim().isEmpty ? builder.order('name').limit(20) : builder.ilike('name', '%${query.trim()}%').order('name').limit(20));
    return (rows as List).map((r) => ShgSearchResult.fromMap(r as Map<String, dynamic>)).toList();
  }
}
