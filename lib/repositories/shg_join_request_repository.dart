import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/shg_join_request.dart';
import '../services/supabase_service.dart';

/// Backed by `public.shg_join_requests` — only meaningful in live
/// (Supabase-configured) mode, since demo mode has no real approval
/// workflow (the demo persona is always instantly "in" the demo SHG).
class ShgJoinRequestRepository {
  SupabaseClient get _client => SupabaseService.instance.client;
  bool get _live => SupabaseService.isConfigured;

  Future<void> submit({required String shgId}) async {
    if (!_live) return;
    // Was a raw DELETE-then-INSERT (two separate network calls) — an
    // interruption between them (dropped connection, backgrounded tab)
    // could leave a member with zero pending rows and no clear way back in.
    // `submit_shg_join_request` (migration 0105) wraps both statements in
    // one plpgsql function body, giving them the same atomicity a single
    // transaction would — SECURITY INVOKER (the default), so RLS still
    // applies exactly as it did for the two separate client calls. Replaces
    // any existing PENDING request instead of colliding with the
    // one-pending-per-member unique index (0004) — a member can reach this
    // call a second time while still awaiting a decision (e.g.
    // ShgApprovalPendingPage's "Choose a different SHG", offered in the
    // pending state too, not just rejected — see 0033). Already-decided
    // (approved/rejected) rows never match the delete filter inside the
    // function, so a leader's/staff's past decision is never touched.
    await _client.rpc('submit_shg_join_request', params: {'p_shg_id': shgId});
  }

  /// The member's own most recent request (so the pending-approval page can
  /// show which SHG they asked to join and whether it was rejected).
  Future<ShgJoinRequest?> fetchMine(String? memberId) async {
    if (!_live || memberId == null) return null;
    final rows = await _client.from('shg_join_requests').select().eq('member_id', memberId).order('requested_at', ascending: false).limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    final map = Map<String, dynamic>.from(list.first as Map<String, dynamic>);
    // `shgs_select_own_or_staff` RLS only allows reading a `shgs` row once
    // you're already a member of it (`id = current_shg_id()`) — a still-
    // PENDING requester never satisfies that (their own `shg_id` is null
    // until approved), so embedding `shgs(name)` directly here always came
    // back null and this page showed "Unknown SHG" for every request that
    // hadn't been approved yet, the common case this page exists for. The
    // pending requester still needs to see which SHG they asked to join, so
    // resolve the name through `shg_directory` instead — the view that
    // exists precisely to expose the safe non-sensitive columns (no
    // bank_account/ifsc) to any authenticated user for onboarding search,
    // which is exactly the access level appropriate here too.
    final shgId = map['shg_id'] as String?;
    if (shgId != null) {
      final shgRows = await _client.from('shg_directory').select('name').eq('id', shgId).limit(1);
      final shgList = shgRows as List;
      if (shgList.isNotEmpty) {
        map['shgs'] = {'name': (shgList.first as Map<String, dynamic>)['name']};
      }
    }
    return ShgJoinRequest.fromMap(map);
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

  /// [asLeader] promotes the requester to 'leader' on approval instead of
  /// leaving her 'member' — the RPC (migration 0116) independently enforces
  /// that only staff (crp/clf/admin) may pass `true` here, matching
  /// ShgJoinRequestsPage's own client-side gate on when to even show that
  /// option. Ignored when [approve] is false.
  Future<void> decide(String requestId, bool approve, {bool asLeader = false}) async {
    if (!_live) return;
    await _client.rpc('approve_shg_join_request', params: {'p_request_id': requestId, 'p_approve': approve, 'p_as_leader': asLeader});
  }

  /// Cancels the member's own still-pending request outright, with no
  /// replacement SHG picked (unlike [submit], which replaces one pending
  /// row with another). RLS-provisioned since migration 0033
  /// (`shg_join_requests_delete_self_pending`) but had no UI entry point
  /// until now — `ShgApprovalPendingPage` only ever offered "Choose a
  /// different SHG", with no way to just stop waiting.
  Future<void> withdraw(String requestId) async {
    if (!_live) return;
    await _client.from('shg_join_requests').delete().eq('id', requestId);
  }
}
