import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/schemes.dart' as mock;
import '../models/scheme.dart';
import '../services/supabase_service.dart';

/// Backed by `public.schemes` / `public.scheme_applications` when Supabase
/// is configured; falls back to `lib/data/schemes.dart` otherwise. The
/// scheme catalog is public reference data, readable by any authenticated
/// user regardless of SHG.
class SchemeRepository {
  SupabaseClient get _client => SupabaseService.instance.client;
  bool get _live => SupabaseService.isConfigured;

  Future<List<Scheme>> fetchSchemes() async {
    if (!_live) {
      return mock.schemes.map((s) => Scheme(id: s.id, name: s.name, fullName: s.fullName, agency: s.agency, benefit: s.benefit, eligibility: s.eligibility, deadline: _parseMockDate(s.deadline))).toList();
    }
    final rows = await _client.from('schemes').select().order('deadline');
    return (rows as List).map((r) => Scheme.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<Scheme?> fetchSchemeById(String id) async {
    if (!_live) {
      final matches = (await fetchSchemes()).where((s) => s.id == id);
      return matches.isEmpty ? null : matches.first;
    }
    final row = await _client.from('schemes').select().eq('id', id).maybeSingle();
    return row == null ? null : Scheme.fromMap(row);
  }

  /// Maps scheme id → the current member's application status (only for
  /// schemes they've applied to).
  Future<Map<String, SchemeApplication>> fetchMyApplications(String? memberId) async {
    if (!_live || memberId == null) {
      final byStatus = <String, SchemeApplication>{};
      for (final s in mock.schemes.where((s) => s.status != 'not_applied')) {
        byStatus[s.id] = SchemeApplication(id: s.id, schemeId: s.id, status: s.status, appliedOn: DateTime.now());
      }
      return byStatus;
    }
    final rows = await _client.from('scheme_applications').select().eq('member_id', memberId);
    final byScheme = <String, SchemeApplication>{};
    for (final r in rows as List) {
      final app = SchemeApplication.fromMap(r as Map<String, dynamic>);
      byScheme[app.schemeId] = app;
    }
    return byScheme;
  }

  Future<void> apply({required String schemeId, required String? memberId}) async {
    if (!_live || memberId == null) return;
    await _client.from('scheme_applications').insert({
      'scheme_id': schemeId,
      'member_id': memberId,
      'status': 'applied',
    });
  }

  /// Admin-only catalog management (enforced server-side by
  /// `schemes_write_admin`).
  Future<void> createScheme({required String name, String? fullName, String? agency, String? benefit, List<String> eligibility = const []}) async {
    if (!_live) return;
    await _client.from('schemes').insert({
      'name': name,
      'full_name': ?fullName,
      'agency': ?agency,
      'benefit': ?benefit,
      'eligibility': eligibility,
    });
  }

  Future<void> updateScheme(String id, {required String name, String? fullName, String? agency, String? benefit}) async {
    if (!_live) return;
    await _client.from('schemes').update({
      'name': name,
      'full_name': fullName,
      'agency': agency,
      'benefit': benefit,
    }).eq('id', id);
  }

  Future<void> deleteScheme(String id) async {
    if (!_live) return;
    await _client.from('schemes').delete().eq('id', id);
  }

  DateTime? _parseMockDate(String? s) {
    if (s == null) return null;
    const months = {'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6, 'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12};
    try {
      final parts = s.split(' ');
      return DateTime(int.parse(parts[2]), months[parts[1]]!, int.parse(parts[0]));
    } catch (_) {
      return null;
    }
  }
}
