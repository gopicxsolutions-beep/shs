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
    final rows = await _client.from('shg_join_requests').select('*, profiles(name)').eq('shg_id', shgId).eq('status', 'pending').order('requested_at');
    return (rows as List).map((r) => ShgJoinRequest.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> decide(String requestId, bool approve) async {
    if (!_live) return;
    await _client.rpc('approve_shg_join_request', params: {'p_request_id': requestId, 'p_approve': approve});
  }
}
