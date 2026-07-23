import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/schemes.dart' as mock;
import '../models/scheme.dart';
import '../services/supabase_service.dart';

/// Thrown by [SchemeRepository.decideApplication] when the application is no
/// longer 'applied'/'under_review' by the time the write reaches the
/// database — i.e. a different staff account already decided it (see
/// `decide_scheme_application` in
/// supabase/migrations/0029_loan_and_scheme_decision_race_guard.sql).
class SchemeApplicationAlreadyDecidedException implements Exception {
  const SchemeApplicationAlreadyDecidedException();
}

/// Backed by `public.schemes` / `public.scheme_applications` when Supabase
/// is configured; falls back to `lib/data/schemes.dart` otherwise. The
/// scheme catalog is public reference data, readable by any authenticated
/// user regardless of SHG.
class SchemeRepository {
  SupabaseClient get _client => SupabaseService.instance.client;
  bool get _live => SupabaseService.isConfigured;

  // Demo mode has no backing table, so applying to a scheme would otherwise
  // never show anywhere — track it here so it survives for the rest of the
  // session, mirroring AnnouncementRepository._locallyRead.
  static final Set<String> _locallyApplied = {};

  // Same idea for the staff decision on an application — see
  // decideApplication()/fetchPendingApplications() below. Keyed by
  // scheme id (mirrors _locallyApplied, since demo mode's single mock
  // member can only have one application per scheme, matching the real
  // schema's `unique (scheme_id, member_id)` constraint).
  static final Map<String, String> _locallyDecided = {};

  // Same idea for admin catalog CRUD — adding/editing/deleting a scheme
  // would otherwise silently revert the moment the catalog reloads.
  static final List<Scheme> _locallyAddedSchemes = [];
  static final Set<String> _locallyDeletedSchemes = {};
  static final Map<String, Scheme> _locallyUpdatedSchemes = {};

  Future<List<Scheme>> fetchSchemes() async {
    if (!_live) {
      final list = mock.schemes
          .where((s) => !_locallyDeletedSchemes.contains(s.id))
          .map((s) => Scheme(
                id: s.id,
                name: s.name,
                fullName: s.fullName,
                agency: s.agency,
                benefit: s.benefit,
                eligibility: s.eligibility,
                criteria: EligibilityCriteria(
                  requiresShgMembership: s.requiresShgMembership,
                  minShgAgeMonths: s.minShgAgeMonths,
                  minShgGrade: s.minShgGrade,
                ),
                deadline: _parseMockDate(s.deadline),
              ))
          .map((s) => _locallyUpdatedSchemes[s.id] ?? s)
          .toList()
        ..addAll(_locallyAddedSchemes);
      // Match the live query's `order('deadline')` — ascending by soonest
      // deadline, with no-deadline schemes sorted last (Postgres' default
      // NULLS LAST for ascending order).
      list.sort((a, b) {
        if (a.deadline == null && b.deadline == null) return 0;
        if (a.deadline == null) return 1;
        if (b.deadline == null) return -1;
        return a.deadline!.compareTo(b.deadline!);
      });
      return list;
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
    if (!_live) {
      final byStatus = <String, SchemeApplication>{};
      for (final s in mock.schemes.where((s) => s.status != 'not_applied' || _locallyApplied.contains(s.id))) {
        final baseStatus = s.status == 'not_applied' ? 'applied' : s.status;
        final status = _locallyDecided[s.id] ?? baseStatus;
        byStatus[s.id] = SchemeApplication(id: s.id, schemeId: s.id, status: status, appliedOn: DateTime.now());
      }
      return byStatus;
    }
    if (memberId == null) return {};
    final rows = await _client.from('scheme_applications').select().eq('member_id', memberId);
    final byScheme = <String, SchemeApplication>{};
    for (final r in rows as List) {
      final app = SchemeApplication.fromMap(r as Map<String, dynamic>);
      byScheme[app.schemeId] = app;
    }
    return byScheme;
  }

  Future<void> apply({required String schemeId, required String? memberId}) async {
    if (!_live) {
      _locallyApplied.add(schemeId);
      return;
    }
    await _client.from('scheme_applications').insert({
      'scheme_id': schemeId,
      'member_id': memberId,
      'status': 'applied',
    });
  }

  /// Staff review queue — `scheme_applications_update_self_or_staff` RLS
  /// already let staff move an application between
  /// applied/under_review/approved/rejected, but until now nothing in the
  /// app ever called that update path: an application, once submitted,
  /// could never actually be approved or rejected by anyone — a real,
  /// core gap for an app whose entire "Government Schemes" module exists
  /// to help members get schemes approved. Only staff (crp/clf/admin) can
  /// reach this per `is_staff()`, matching the RLS's own staff-only write
  /// scope (unlike loan approvals, this isn't leader-scoped — scheme
  /// eligibility/approval is a govt-scheme-administration matter, not an
  /// individual SHG's own call).
  Future<List<SchemeApplicationReview>> fetchPendingApplications() async {
    if (!_live) {
      final schemes = await fetchSchemes();
      // Must include the catalog's own preset 'applied'/'under_review' rows
      // (sc2 PMEGP, sc3 MUDRA — see lib/data/schemes.dart), not just schemes
      // applied to during this session via apply(): fetchMyApplications()
      // already surfaces those preset rows to the member as pending
      // applications, so if this queue only looked at _locallyApplied, the
      // member's own "My Applications" list and the staff review queue
      // would disagree about the same underlying demo data — the staff
      // queue would sit empty even though the member view shows real
      // pending applications, unlike live mode's `inFilter('status', ...)`
      // which would surface matching rows for equivalent data.
      final presetPendingIds = mock.schemes.where((s) => s.status == 'applied' || s.status == 'under_review').map((s) => s.id);
      final pendingIds = {...presetPendingIds, ..._locallyApplied}.where((schemeId) => !_locallyDecided.containsKey(schemeId));
      return pendingIds
          .map((schemeId) {
            final matches = schemes.where((s) => s.id == schemeId);
            final schemeName = matches.isEmpty ? schemeId : matches.first.name;
            return SchemeApplicationReview(applicationId: schemeId, schemeId: schemeId, schemeName: schemeName, memberName: 'Lakshmi Devi', status: 'applied', appliedOn: DateTime.now());
          })
          .toList();
    }
    final rows = await _client
        .from('scheme_applications')
        .select('id, scheme_id, status, applied_on, schemes(name), profiles(name)')
        .inFilter('status', ['applied', 'under_review'])
        .order('applied_on');
    return (rows as List).map((r) => SchemeApplicationReview.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> decideApplication(String applicationId, {required bool approve}) async {
    if (!_live) {
      _locallyDecided[applicationId] = approve ? 'approved' : 'rejected';
      return;
    }
    // Atomic via `decide_scheme_application` (see
    // supabase/migrations/0029_loan_and_scheme_decision_race_guard.sql) —
    // locks the row and verifies it's still applied/under_review before
    // transitioning, so a second staff account racing on the same shared
    // review queue can no longer silently overwrite the first decision.
    try {
      await _client.rpc('decide_scheme_application', params: {'p_application_id': applicationId, 'p_approve': approve});
    } on PostgrestException catch (e) {
      // 'PGRST202' = function not found in schema cache — migration 0029
      // not deployed yet. Falls back to the old non-atomic write (same
      // fallback shape used elsewhere in this repository layer for
      // not-yet-deployed migrations).
      if (e.code == 'PGRST202') {
        await _client.from('scheme_applications').update({'status': approve ? 'approved' : 'rejected'}).eq('id', applicationId);
        return;
      }
      if (e.message.contains('already decided')) throw const SchemeApplicationAlreadyDecidedException();
      rethrow;
    }
  }

  /// Admin-only catalog management (enforced server-side by
  /// `schemes_write_admin`). [criteria] backs the structured eligibility
  /// rules engine (see `EligibilityCriteria` in `lib/models/scheme.dart`) —
  /// defaults to "no structured criteria", matching a scheme whose
  /// eligibility is manual-verification-only via the free-text [eligibility]
  /// list.
  Future<void> createScheme({
    required String name,
    String? fullName,
    String? agency,
    String? benefit,
    List<String> eligibility = const [],
    EligibilityCriteria criteria = const EligibilityCriteria(),
  }) async {
    if (!_live) {
      _locallyAddedSchemes.add(Scheme(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        fullName: fullName,
        agency: agency,
        benefit: benefit,
        eligibility: eligibility,
        criteria: criteria,
      ));
      return;
    }
    await _client.from('schemes').insert({
      'name': name,
      'full_name': ?fullName,
      'agency': ?agency,
      'benefit': ?benefit,
      'eligibility': eligibility,
      'eligibility_criteria': criteria.toMap(),
    });
  }

  Future<void> updateScheme(String id, {required String name, String? fullName, String? agency, String? benefit, EligibilityCriteria criteria = const EligibilityCriteria()}) async {
    if (!_live) {
      final current = (await fetchSchemes()).where((s) => s.id == id);
      final eligibility = current.isEmpty ? const <String>[] : current.first.eligibility;
      final updated = Scheme(id: id, name: name, fullName: fullName, agency: agency, benefit: benefit, eligibility: eligibility, criteria: criteria);
      final addedIdx = _locallyAddedSchemes.indexWhere((s) => s.id == id);
      if (addedIdx != -1) {
        _locallyAddedSchemes[addedIdx] = updated;
      } else {
        _locallyUpdatedSchemes[id] = updated;
      }
      return;
    }
    await _client.from('schemes').update({
      'name': name,
      'full_name': fullName,
      'agency': agency,
      'benefit': benefit,
      'eligibility_criteria': criteria.toMap(),
    }).eq('id', id);
  }

  Future<void> deleteScheme(String id) async {
    if (!_live) {
      _locallyAddedSchemes.removeWhere((s) => s.id == id);
      _locallyDeletedSchemes.add(id);
      return;
    }
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
