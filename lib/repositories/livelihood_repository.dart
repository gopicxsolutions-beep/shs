import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/livelihood.dart' as mock;
import '../data/members.dart' as mock_members;
import '../models/livelihood.dart';
import '../models/types.dart';
import '../services/supabase_service.dart';

/// Backed by `public.livelihood_activities` when Supabase is configured;
/// falls back to `lib/data/livelihood.dart` otherwise.
class LivelihoodRepository {
  SupabaseClient get _client => SupabaseService.instance.client;
  bool get _live => SupabaseService.isConfigured;

  Future<List<LivelihoodActivity>> fetchForShg(String? shgId) async {
    if (!_live || shgId == null) return _mockActivities();
    final rows = await _client.from('livelihood_activities').select('*, profiles(name)').eq('shg_id', shgId).order('created_at', ascending: false);
    return (rows as List).map((r) => LivelihoodActivity.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<List<LivelihoodActivity>> fetchForMember(String? memberId) async {
    // Demo mode has no real per-member session, so `_mockActivities()` is
    // scoped to the requested member's own activities (resolved to a name
    // since the mock data keys on memberName, not id) rather than returning
    // everyone's.
    if (!_live || memberId == null) return _mockActivities().where((a) => a.memberName == _demoMemberName(memberId)).toList();
    final rows = await _client.from('livelihood_activities').select('*, profiles(name)').eq('member_id', memberId).order('created_at', ascending: false);
    return (rows as List).map((r) => LivelihoodActivity.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<LivelihoodActivity?> fetchById(String id) async {
    if (!_live) {
      final matches = _mockActivities().where((a) => a.id == id);
      return matches.isEmpty ? null : matches.first;
    }
    final row = await _client.from('livelihood_activities').select('*, profiles(name)').eq('id', id).maybeSingle();
    return row == null ? null : LivelihoodActivity.fromMap(row);
  }

  Future<void> addActivity({
    required String? memberId,
    required String? shgId,
    required String activityType,
    required String description,
    required num investment,
  }) async {
    if (!_live || memberId == null || shgId == null) return;
    await _client.from('livelihood_activities').insert({
      'shg_id': shgId,
      'member_id': memberId,
      'activity_type': activityType,
      'description': description,
      'investment': investment,
      'revenue': 0,
      'status': 'planned',
    });
  }

  Future<void> updateProgress(String id, {required num revenue, required String status}) async {
    if (!_live) return;
    await _client.from('livelihood_activities').update({'revenue': revenue, 'status': status}).eq('id', id);
  }

  String _demoMemberName(String? memberId) {
    if (memberId == null) return defaultUser.name;
    final match = mock_members.members.where((m) => m.id == memberId);
    return match.isEmpty ? defaultUser.name : match.first.name;
  }

  List<LivelihoodActivity> _mockActivities() => mock.livelihoodActivities
      .map((a) => LivelihoodActivity(
            id: a.id,
            memberId: a.id,
            memberName: a.memberName,
            activityType: a.activityType,
            description: a.description,
            investment: a.investment,
            revenue: a.revenue,
            status: a.status,
          ))
      .toList();
}
