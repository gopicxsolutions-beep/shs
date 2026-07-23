import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/members.dart' as mock_members;
import '../data/shg.dart' as mock;
import '../models/paged_result.dart';
import '../models/shg.dart';
import '../services/supabase_service.dart';
import 'admin_repository.dart';

/// Backed by `public.shgs` / `public.profiles` / `public.shg_documents` when
/// Supabase is configured; falls back to `lib/data/shg.dart` /
/// `lib/data/members.dart` otherwise (same dual-mode pattern as the other
/// repositories).
class ShgRepository {
  SupabaseClient get _client => SupabaseService.instance.client;
  bool get _live => SupabaseService.isConfigured;

  // Test-only seams (both null by default, so every existing test keeps
  // seeing the exact short mock.ShgInfo.name / mock_members.members values
  // it always has). test/routes/long_content_stress_test.dart sets these to
  // exercise a realistic long SHG name / member name at a normal viewport,
  // then resets them — no change to lib/data/**'s shared mock records
  // themselves.
  static String? debugShgNameOverride;
  static List<mock_members.Member>? debugMembersOverride;

  // Demo mode has no backing table, so an added document would otherwise
  // vanish the instant the list reloads — track it here so it survives for
  // the rest of the session, mirroring AnnouncementRepository._locallyRead.
  static final List<ShgDocument> _locallyAdded = [];

  // Same idea for admin-created SHGs (see AdminShgsPage) — created via
  // createShg(), listed in fetchAllShgs() alongside the one fixed demo SHG.
  static final List<ShgProfile> _locallyAddedShgs = [];

  // Same idea for admin-edited SHGs (see AdminShgsPage's Edit dialog and
  // updateShg() below) — keyed by id so it also covers edits to the one
  // fixed demo SHG ('demo-shg'), which never appears in _locallyAddedShgs.
  static final Map<String, ShgProfile> _locallyUpdatedShgs = {};

  /// Every SHG in the catalog — backs AdminShgsPage. `shgs_insert_staff`
  /// already permits any staff role to create one, so this needed no schema
  /// change; the client simply never had a UI for it (see AdminShgsPage's
  /// doc comment for why that mattered more than it sounds).
  ///
  /// Used to hard-cap live mode at a single `.limit(500)` query ordered
  /// alphabetically, which silently and permanently hid any SHG past the
  /// 500th name with no way to reach them. Now paginated by real keyset
  /// cursor instead — see `AdminRepository.fetchAllUsers`'s doc comment
  /// (same [PagedResult] shape, same `afterName`/`pageSize`/one-extra-row
  /// trick, and the same known name-collision tie-break edge case).
  Future<PagedResult<ShgProfile>> fetchAllShgs({String? afterName, int pageSize = 100}) async {
    if (!_live) {
      // Demo mode's mock catalog is small and fixed — always one page, no
      // real pagination need. `_locallyUpdatedShgs` overrides the fixed demo
      // SHG's row if an admin edited it via updateShg() below — entries
      // already added via createShg() are updated in place in
      // _locallyAddedShgs itself, so this lookup only ever matters for
      // 'demo-shg'.
      final list = [
        ShgProfile(
          id: 'demo-shg',
          name: debugShgNameOverride ?? mock.ShgInfo.name,
          // Matches fetchShg()'s own demo-mode formationDate wiring below —
          // without this, AdminShgsPage's Edit dialog (which reads its
          // initial values from this list, not from fetchShg()) would show
          // "Not set" for the demo SHG's formation date even though
          // mock.ShgInfo.formationDate has held a real value all along.
          formationDate: _parseMockDate(mock.ShgInfo.formationDate),
          village: mock.ShgInfo.village,
          mandal: mock.ShgInfo.mandal,
          district: mock.ShgInfo.district,
          state: mock.ShgInfo.state,
          grade: mock.ShgInfo.grade,
        ),
        ..._locallyAddedShgs,
      ].map((s) => _locallyUpdatedShgs[s.id] ?? s).toList();
      return PagedResult(items: list, hasMore: false);
    }
    var builder = _client.from('shgs').select();
    if (afterName != null) builder = builder.gt('name', afterName);
    final rows = await builder.order('name').limit(pageSize + 1);
    final list = (rows as List).map((r) => ShgProfile.fromMap(r as Map<String, dynamic>)).toList();
    final hasMore = list.length > pageSize;
    return PagedResult(items: hasMore ? list.sublist(0, pageSize) : list, hasMore: hasMore);
  }

  /// [formationDate]/[grade] back the structured scheme-eligibility rules
  /// engine's `minShgAgeMonths`/`minShgGrade` criteria (`EligibilityCriteria`
  /// in `lib/models/scheme.dart`) — both optional/nullable, since a
  /// newly-onboarded SHG may not have either fact yet (grade in particular
  /// is an externally-assessed rating, not something set at onboarding
  /// time). Without a write path for these, no SHG created through this app
  /// could ever satisfy a scheme requiring a minimum SHG age or grade.
  Future<void> createShg({
    required String name,
    String? village,
    String? mandal,
    String? district,
    String? state,
    DateTime? formationDate,
    String? grade,
  }) async {
    if (!_live) {
      _locallyAddedShgs.add(ShgProfile(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        village: village,
        mandal: mandal,
        district: district,
        state: state,
        formationDate: formationDate,
        grade: grade,
      ));
      return;
    }
    final formationDateStr = formationDate?.toIso8601String().split('T').first;
    await _client.from('shgs').insert({
      'name': name,
      'village': ?village,
      'mandal': ?mandal,
      'district': ?district,
      'state': ?state,
      'formation_date': ?formationDateStr,
      'grade': ?grade,
    });
  }

  /// Edits an existing SHG's core profile fields — until now there was no
  /// Edit-SHG UI anywhere in the app (see AdminShgsPage's Edit dialog), so an
  /// SHG onboarded without a formation date/grade (or with a typo in its
  /// name/village/district) had no in-app way to ever correct that. Scoped
  /// to exactly the fields AdminShgsPage's Add/Edit dialogs manage — mandal/
  /// state aren't exposed there (matching the pre-existing Add dialog), so
  /// this deliberately never touches those columns, live or demo.
  Future<void> updateShg(
    String id, {
    required String name,
    String? village,
    String? district,
    DateTime? formationDate,
    String? grade,
  }) async {
    if (!_live) {
      final addedIdx = _locallyAddedShgs.indexWhere((s) => s.id == id);
      // Preserves every field this dialog doesn't manage (bank details,
      // clf/vo, mandal/state, ...) by basing the update on the fullest
      // record already known for this id, rather than silently wiping them.
      final base = addedIdx != -1 ? _locallyAddedShgs[addedIdx] : (_locallyUpdatedShgs[id] ?? await fetchShg(id) ?? ShgProfile(id: id, name: name));
      final updated = ShgProfile(
        id: id,
        name: name,
        regNumber: base.regNumber,
        formationDate: formationDate,
        village: village,
        mandal: base.mandal,
        district: district,
        state: base.state,
        bankName: base.bankName,
        bankAccount: base.bankAccount,
        ifsc: base.ifsc,
        grade: grade,
        clf: base.clf,
        vo: base.vo,
      );
      if (addedIdx != -1) {
        _locallyAddedShgs[addedIdx] = updated;
      } else {
        _locallyUpdatedShgs[id] = updated;
      }
      return;
    }
    await _client.from('shgs').update({
      'name': name,
      'village': village,
      'district': district,
      'formation_date': formationDate?.toIso8601String().split('T').first,
      'grade': grade,
    }).eq('id', id);
  }

  Future<ShgProfile?> fetchShg(String? shgId) async {
    if (!_live) {
      final base = ShgProfile(
        id: 'demo-shg',
        name: debugShgNameOverride ?? mock.ShgInfo.name,
        regNumber: mock.ShgInfo.regNumber,
        // Wired through so the demo persona's SHG actually has a
        // registration age — without this, SchemeEligibilityPage's
        // `minShgAgeMonths` structured criterion could never show a "met"
        // result in demo mode (shgAgeMonths would always resolve to null,
        // the fail-safe "isn't on record" branch), even though
        // `mock.ShgInfo.formationDate` has held a real value all along.
        formationDate: _parseMockDate(mock.ShgInfo.formationDate),
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
      // Reflects an admin's edit to the demo SHG's formation date/grade (see
      // AdminShgsPage's Edit dialog / updateShg() above) — without this, the
      // edit would show up on the Manage SHGs list but nowhere else that
      // reads a member's own SHG (e.g. SchemeEligibilityPage), which would
      // look exactly like the edit silently didn't take.
      return _locallyUpdatedShgs['demo-shg'] ?? base;
    }
    // A live staff account (admin/crp/clf) legitimately has no SHG — see
    // profile_setup_page.dart. Callers (e.g. ProfilePage's "Not yet
    // approved" fallback) rely on null here, not on demo data standing in.
    if (shgId == null) return null;
    final row = await _client.from('shgs').select().eq('id', shgId).maybeSingle();
    return row == null ? null : ShgProfile.fromMap(row);
  }

  // Mock data's role field ('President'/'Secretary'/'Treasurer'/'Member')
  // doesn't match the DB's role vocabulary ('leader'/'member'/etc.) that
  // AppBadge's role-tone lookup (shg_members_page.dart/member_detail_page.dart)
  // keys on — without this mapping, demo mode's leadership roles rendered
  // as an unstyled "president"/"secretary"/"treasurer" badge instead of a
  // styled "Leader" one. Mirrors AdminRepository._mockRoleMap, which
  // already got this right for the same underlying mock data.
  static const _mockRoleMap = <String, String>{'President': 'leader', 'Secretary': 'leader', 'Treasurer': 'leader', 'Member': 'member'};

  Future<List<Member>> fetchMembers(String? shgId) async {
    if (!_live) {
      return (debugMembersOverride ?? mock_members.members)
          .map((m) => Member(id: m.id, name: m.name, mobile: m.mobile, role: AdminRepository.roleOverride(m.id, _mockRoleMap[m.role] ?? 'member'), village: null))
          .toList();
    }
    if (shgId == null) return [];
    final rows = await _client.from('profiles').select().eq('shg_id', shgId).order('name');
    return (rows as List).map((r) => Member.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<Member?> fetchMember(String id) async {
    if (!_live) {
      final matches = (debugMembersOverride ?? mock_members.members).where((m) => m.id == id);
      if (matches.isEmpty) return null;
      final m = matches.first;
      return Member(id: m.id, name: m.name, mobile: m.mobile, role: AdminRepository.roleOverride(m.id, _mockRoleMap[m.role] ?? 'member'), village: null);
    }
    final row = await _client.from('profiles').select().eq('id', id).maybeSingle();
    return row == null ? null : Member.fromMap(row);
  }

  Future<List<ShgDocument>> fetchDocuments(String? shgId) async {
    if (!_live) {
      return [
        ..._locallyAdded.reversed,
        ...mock.documents.map((d) => ShgDocument(id: d.id, name: d.name, type: d.type, size: d.size, createdAt: _parseMockDate(d.date))),
      ];
    }
    if (shgId == null) return [];
    final rows = await _client.from('shg_documents').select().eq('shg_id', shgId).order('created_at', ascending: false);
    return (rows as List).map((r) => ShgDocument.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Records a document's metadata once its file has already been uploaded
  /// to the `shg-documents` Storage bucket via [uploadDocument] (real
  /// `storagePath`) — or, in demo mode, records the picked file's name/size
  /// only, since there's no backing bucket to upload to.
  /// Returns whether the document record was actually saved — `false`
  /// (not an exception) when a live staff account has no SHG to attach it
  /// to, so the caller can tell that apart from a genuine success instead
  /// of showing "Document added" for a write that never happened.
  Future<bool> addDocument({required String? shgId, required String name, required String type, String? size, String? storagePath}) async {
    if (!_live) {
      _locallyAdded.add(ShgDocument(id: 'local-${DateTime.now().microsecondsSinceEpoch}', name: name, type: type, size: size, createdAt: DateTime.now()));
      return true;
    }
    if (shgId == null) return false;
    await _client.from('shg_documents').insert({
      'shg_id': shgId,
      'name': name,
      'type': type,
      'size': ?size,
      'storage_path': ?storagePath,
    });
    return true;
  }

  /// Uploads a picked file's bytes to the `shg-documents` bucket under this
  /// SHG's own folder (`{shgId}/{filename}`) — the same folder convention
  /// `0005_storage_buckets.sql`'s RLS policies key off of
  /// (`(storage.foldername(name))[1] = current_shg_id()`). Returns the
  /// storage path to persist via [addDocument]. The bucket enforces a 10 MiB
  /// size cap and a PDF/JPEG/PNG/WEBP allow-list server-side
  /// (`0028_storage_bucket_size_and_type_limits.sql`) — a rejected upload
  /// throws a `StorageException`, surfaced by the caller as a friendly error.
  Future<String> uploadDocument({required String shgId, required Uint8List bytes, required String fileName, required String contentType}) async {
    final path = '$shgId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await _client.storage.from('shg-documents').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: contentType));
    return path;
  }

  /// A short-lived signed URL to view/download a private `shg-documents`
  /// file — the bucket itself is private (unlike `product-images`), so a
  /// permanent public URL isn't possible; RLS on `storage.objects` still
  /// governs who can even request a signed URL for a given path (same-SHG
  /// member or staff only).
  Future<String> getDownloadUrl(String storagePath) => _client.storage.from('shg-documents').createSignedUrl(storagePath, 60);

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
