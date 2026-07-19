import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/members.dart' as mock_members;
import '../data/shg.dart' as mock;
import '../models/shg.dart';
import '../services/supabase_service.dart';

/// Backed by `public.shgs` / `public.profiles` / `public.shg_documents` when
/// Supabase is configured; falls back to `lib/data/shg.dart` /
/// `lib/data/members.dart` otherwise (same dual-mode pattern as the other
/// repositories).
class ShgRepository {
  SupabaseClient get _client => SupabaseService.instance.client;
  bool get _live => SupabaseService.isConfigured;

  // Demo mode has no backing table, so an added document would otherwise
  // vanish the instant the list reloads — track it here so it survives for
  // the rest of the session, mirroring AnnouncementRepository._locallyRead.
  static final List<ShgDocument> _locallyAdded = [];

  Future<ShgProfile?> fetchShg(String? shgId) async {
    if (!_live || shgId == null) {
      return ShgProfile(
        id: 'demo-shg',
        name: mock.ShgInfo.name,
        regNumber: mock.ShgInfo.regNumber,
        village: mock.ShgInfo.village,
        mandal: mock.ShgInfo.mandal,
        district: mock.ShgInfo.district,
        state: mock.ShgInfo.state,
        bankName: mock.ShgInfo.bankName,
        bankAccount: mock.ShgInfo.bankAccount,
        ifsc: mock.ShgInfo.ifsc,
        grade: mock.ShgInfo.grade,
        clf: mock.ShgInfo.clf,
        vo: mock.ShgInfo.vo,
      );
    }
    final row = await _client.from('shgs').select().eq('id', shgId).maybeSingle();
    return row == null ? null : ShgProfile.fromMap(row);
  }

  Future<List<Member>> fetchMembers(String? shgId) async {
    if (!_live || shgId == null) {
      return mock_members.members.map((m) => Member(id: m.id, name: m.name, mobile: m.mobile, role: m.role.toLowerCase(), village: null)).toList();
    }
    final rows = await _client.from('profiles').select().eq('shg_id', shgId).order('name');
    return (rows as List).map((r) => Member.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<Member?> fetchMember(String id) async {
    if (!_live) {
      final matches = mock_members.members.where((m) => m.id == id);
      if (matches.isEmpty) return null;
      final m = matches.first;
      return Member(id: m.id, name: m.name, mobile: m.mobile, role: m.role.toLowerCase(), village: null);
    }
    final row = await _client.from('profiles').select().eq('id', id).maybeSingle();
    return row == null ? null : Member.fromMap(row);
  }

  Future<List<ShgDocument>> fetchDocuments(String? shgId) async {
    if (!_live || shgId == null) {
      return [
        ..._locallyAdded.reversed,
        ...mock.documents.map((d) => ShgDocument(id: d.id, name: d.name, type: d.type, size: d.size, createdAt: _parseMockDate(d.date))),
      ];
    }
    final rows = await _client.from('shg_documents').select().eq('shg_id', shgId).order('created_at', ascending: false);
    return (rows as List).map((r) => ShgDocument.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Records a document's metadata. Actual file upload needs a Supabase
  /// Storage bucket + a file-picker plugin (neither wired yet — see
  /// docs/DEVELOPMENT_PROGRESS.md); this persists the record once a
  /// `storagePath` is available from that upload step.
  Future<void> addDocument({required String? shgId, required String name, required String type, String? storagePath}) async {
    if (!_live) {
      _locallyAdded.add(ShgDocument(id: 'local-${DateTime.now().microsecondsSinceEpoch}', name: name, type: type, createdAt: DateTime.now()));
      return;
    }
    if (shgId == null) return;
    await _client.from('shg_documents').insert({
      'shg_id': shgId,
      'name': name,
      'type': type,
      'storage_path': ?storagePath,
    });
  }

  DateTime _parseMockDate(String s) {
    const months = {'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6, 'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12};
    try {
      final parts = s.split(' ');
      return DateTime(int.parse(parts[2]), months[parts[1]]!, int.parse(parts[0]));
    } catch (_) {
      return DateTime.now();
    }
  }
}
