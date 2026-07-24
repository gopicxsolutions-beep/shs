import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/shg_join_request.dart';
import '../services/supabase_service.dart';

/// Backed by `public.shg_join_requests` — only meaningful in live
/// (Supabase-configured) mode, since demo mode has no real approval
/// workflow (the demo persona is always instantly "in" the demo SHG).
class ShgJoinRequestRepository {
  SupabaseClient get _client => SupabaseService.instance.client;
  bool get _live => SupabaseService.isConfigured;

  Future<void> submit({required String memberId, required String shgId}) async {
    if (!_live) return;
    // Replace any existing PENDING request instead of colliding with the
    // one-pending-per-member unique index (0004) — a member can reach this
    // call a second time while still awaiting a decision (e.g.
    // ShgApprovalPendingPage's "Choose a different SHG", offered in the
    // pending state too, not just rejected — see 0033), and without this
    // the insert below throws a raw constraint-violation error instead of
    // letting her actually change her mind. Already-decided (approved/
    // rejected) rows never match this filter, so a leader's/staff's past
    // decision is never touched — matches the delete policy 0033 backs
    // this with (`status = 'pending'` only).
    await _client.from('shg_join_requests').delete().eq('member_id', memberId).eq('status', 'pending');
    await _client.from('shg_join_requests').insert({'member_id': memberId, 'shg_id': shgId});
  }

  /// The member's own most recent request (so the pending-approval page can
  /// show which SHG they asked to join and whether it was rejected).
  Future<ShgJoinRequest?> fetchMine(String? memberId) async {
    if (!_live || memberId == null) return null;
    final rows = await _client.from('shg_join_requests').select('*, shgs(name)').eq('member_id', memberId).order('requested_at', ascending: false).limit(1);
    final list = rows as List;
    return list.isEmpty ? null : ShgJoinRequest.fromMap(list.first as Map<String, dynamic>);
  }

  /// Pending requests for the leader's own SHG.
  Future<List<ShgJoinRequest>> fetchPendingForShg(String? shgId) async {
    if (!_live || shgId == null) return const [];
    // `profiles!member_id(name, mobile)`, not the bare `profiles(name)` this
    // used to say: `shg_join_requests` has TWO foreign keys into `profiles`
    // (`member_id` and `decided_by`), so an unqualified `profiles(...)` embed
    // is genuinely ambiguous to PostgREST — it has no way to know which
    // relationship to join through, and errors the entire query rather than
    // guessing. This was a real, previously-undiscovered bug: this call
    // could never have succeeded in live mode at all, for any request,
    // regardless of RLS — found only because promoting this page (see
    // migration 0045's profiles RLS fix) to actually add `mobile` to the
    // embed and exercising the page live surfaced the AppAsyncBuilder error
    // state immediately. The explicit `!member_id` hint disambiguates:
    // always join through the requester's own id, never `decided_by`.
    // `mobile` lets a leader distinguish two same-named requesters or
    // sanity-check identity, not just see a bare name — see migration
    // 0045's own header for why `name` alone was already unavailable.
    final rows = await _client.from('shg_join_requests').select('*, profiles!member_id(name, mobile)').eq('shg_id', shgId).eq('status', 'pending').order('requested_at');
    return (rows as List).map((r) => ShgJoinRequest.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> decide(String requestId, bool approve) async {
    if (!_live) return;
    await _client.rpc('approve_shg_join_request', params: {'p_request_id': requestId, 'p_approve': approve});
  }
}
