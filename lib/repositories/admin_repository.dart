import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/analytics.dart' as mock_analytics;
import '../data/members.dart' as mock;
import '../data/shg.dart' as mock_shg;
import '../models/admin.dart';
import '../models/paged_result.dart';
import '../models/profile.dart';
import '../services/supabase_service.dart';
import 'scheme_repository.dart';
import 'training_repository.dart';

const _mockRoleMap = <String, String>{
  'President': 'leader',
  'Secretary': 'leader',
  'Treasurer': 'leader',
  'Member': 'member',
};

/// Backed by `public.profiles` (user management, admin-only writes per
/// `profiles_update_self_or_admin`) and computed table counts for system
/// monitoring (see [SystemHealth] — a documented placeholder for real
/// infra metrics). Scheme catalog CRUD lives on [SchemeRepository] since
/// it's the same table the member-facing Schemes module already reads.
class AdminRepository {
  SupabaseClient get _client => SupabaseService.instance.client;
  bool get _live => SupabaseService.isConfigured;

  // Demo mode has no backing table, so a role change would otherwise revert
  // the instant the user list reloads — track it here so it survives for
  // the rest of the session, mirroring AnnouncementRepository._locallyRead.
  static final Map<String, String> _locallyUpdatedRoles = {};

  // Test-only seam (null by default, so every existing test keeps seeing
  // the exact short mock.members it always has).
  // test/routes/long_content_stress_test.dart sets this (in lockstep with
  // ShgRepository.debugMembersOverride, which it mirrors — kept as a
  // separate field rather than a shared import to avoid a new cross-
  // repository dependency existing only for this test seam) to exercise a
  // realistic long member name at a normal viewport, then resets it — no
  // change to lib/data/members.dart's shared mock records themselves.
  static List<mock.Member>? debugMembersOverride;

  /// Lets [ShgRepository]'s demo branch (fetchMembers/fetchMember) reflect
  /// a role change made here via Manage Users — otherwise an admin
  /// promoting/demoting a member in this repository's own local store
  /// never showed up in that member's own "My SHG" roster or profile badge
  /// for the rest of the "Preview as" session, one role's view silently
  /// disagreeing with another's for the same underlying member.
  static String roleOverride(String userId, String fallback) => _locallyUpdatedRoles[userId] ?? fallback;

  /// Every user on the platform, not scoped to any one SHG — AdminUsersPage
  /// has no search/filter to narrow this, only "Load more" (see
  /// [PagedResult]). Used to hard-cap live mode at a single `.limit(500)`
  /// query ordered alphabetically, which silently and permanently hid any
  /// user past the 500th name with no way to reach them. Now paginated by
  /// real keyset cursor instead: pass [afterName] (the last-seen page's
  /// final row's `name`) to fetch the next page; the first call omits it.
  ///
  /// Fetches one extra row beyond [pageSize] to detect whether more rows
  /// exist, instead of a separate `COUNT` query. Known edge case: the
  /// cursor is `name` alone (no secondary tie-break column such as `id`),
  /// so two rows sharing the *exact* same name at a page boundary could
  /// have one silently skipped on the next page — accepted as a much
  /// smaller gap than the previous total inaccessibility of anything past
  /// row 500, given how rare exact name collisions are for this list.
  Future<PagedResult<Profile>> fetchAllUsers({String? afterName, int pageSize = 100}) async {
    if (!_live) {
      // Demo mode's mock roster is small and fixed — always one page, no
      // real pagination need.
      final list = (debugMembersOverride ?? mock.members)
          .map((m) => Profile(id: m.id, name: m.name, mobile: m.mobile, role: _locallyUpdatedRoles[m.id] ?? _mockRoleMap[m.role] ?? 'member', shgId: _locallyAssignedShgs[m.id] ?? 'demo-shg', village: null))
          .toList();
      return PagedResult(items: list, hasMore: false);
    }
    var builder = _client.from('profiles').select();
    if (afterName != null) builder = builder.gt('name', afterName);
    final rows = await builder.order('name').limit(pageSize + 1);
    final list = (rows as List).map((r) => Profile.fromMap(r as Map<String, dynamic>)).toList();
    final hasMore = list.length > pageSize;
    return PagedResult(items: hasMore ? list.sublist(0, pageSize) : list, hasMore: hasMore);
  }

  Future<void> updateUserRole(String userId, String role) async {
    if (!_live) {
      _locallyUpdatedRoles[userId] = role;
      return;
    }
    await _client.from('profiles').update({'role': role}).eq('id', userId);
  }

  // Same demo-mode local-tracking shape as _locallyUpdatedRoles, above.
  static final Map<String, String> _locallyAssignedShgs = {};

  Future<void> assignShg(String userId, String shgId) async {
    if (!_live) {
      _locallyAssignedShgs[userId] = shgId;
      return;
    }
    await _client.from('profiles').update({'shg_id': shgId}).eq('id', userId);
  }

  Future<List<ShgSearchResult>> searchShgs(String query) async {
    if (!_live) return const [];
    final builder = _client.from('shg_directory').select();
    final rows = await (query.trim().isEmpty ? builder.limit(20) : builder.ilike('name', '%${query.trim()}%').limit(20));
    return (rows as List).map((r) => ShgSearchResult.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<SystemHealth> fetchSystemHealth() async {
    if (!_live) {
      // totalUsers/totalShgs mirror the same platform-wide figures the
      // Admin dashboard shows (Kpis.activeMembers, the village breakdown's
      // SHG count) rather than this demo persona's own single-SHG roster
      // (12 members, 1 SHG) — that mismatch (2142 vs 12, 124 vs 1) made
      // System Monitoring directly contradict the dashboard one tap away.
      final totalShgs = mock_analytics.villageWiseSHGs.fold<int>(0, (s, v) => s + v.shgs);
      return SystemHealth(totalUsers: mock_analytics.Kpis.activeMembers, totalShgs: totalShgs, totalSavingsEntries: 48, totalLoans: 6, pendingLoans: 1, checkedAt: DateTime.now());
    }
    final users = await _client.from('profiles').select('id');
    final shgs = await _client.from('shgs').select('id');
    final savings = await _client.from('savings_entries').select('id');
    final loans = await _client.from('loans').select('id, status');
    final pendingLoans = (loans as List).where((r) => (r as Map<String, dynamic>)['status'] == 'pending').length;
    return SystemHealth(
      totalUsers: (users as List).length,
      totalShgs: (shgs as List).length,
      totalSavingsEntries: (savings as List).length,
      totalLoans: loans.length,
      pendingLoans: pendingLoans,
      checkedAt: DateTime.now(),
    );
  }

  /// Backs the Admin dashboard's "Training Completion" stat, "pending
  /// verification" banner, and "Recent System Activity" feed — all three
  /// used to be static constants in `admin_dashboard.dart` that never
  /// changed no matter what happened on the platform (see
  /// [AdminDashboardStats]'s doc comment). System uptime is deliberately
  /// not computed here — see the same doc comment for why that one figure
  /// stays a labeled placeholder on the dashboard itself.
  Future<AdminDashboardStats> fetchDashboardStats() async {
    if (!_live) {
      // Routed through TrainingRepository/SchemeRepository themselves —
      // not the static mock catalogs directly — so this reflects whatever
      // those repositories' own mutable demo-mode state currently says
      // (TrainingRepository._locallyCertified via markCertified(),
      // SchemeRepository._locallyApplied/_locallyDecided via
      // apply()/decideApplication()). Reading the const mock lists directly
      // made this go stale the instant a demo user actually certified a
      // course or a staff account actually decided an application — the
      // dashboard kept showing the session's starting numbers forever.
      final progress = await TrainingRepository().fetchMyProgress(null);
      final trainingCompletionPct = progress.isEmpty ? 0 : (progress.values.map((c) => c.progress).reduce((a, b) => a + b) / progress.length).round();
      final pendingReviewCount = (await SchemeRepository().fetchPendingApplications()).length;

      // "Recent activity" assembled the same way the live branch below
      // does — real (if fixed/demo) rows from a couple of different mock
      // tables, merged and sorted by their own date, not a disconnected
      // fabricated list.
      final docActivity = mock_shg.documents.map((d) => AdminActivityItem(kind: AdminActivityKind.document, subjectName: d.name, occurredAt: _parseMockDate(d.date)));
      final memberActivity = (debugMembersOverride ?? mock.members).map((m) => AdminActivityItem(kind: AdminActivityKind.newUser, subjectName: m.name, occurredAt: _parseMockDate(m.joiningDate)));
      final activity = [...docActivity, ...memberActivity]..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

      return AdminDashboardStats(trainingCompletionPct: trainingCompletionPct, pendingReviewCount: pendingReviewCount, recentActivity: activity.take(5).toList());
    }

    // Average completion across every member/course pair platform-wide —
    // `is_staff()` lets this bypass `course_progress_select_related`'s
    // normal member-scoped read (supabase/migrations/0037_select_scope_
    // overexposure_fix.sql).
    //
    // The denominator is every (member × course) pair that could exist, not
    // just the course_progress rows that already do — a member who has
    // never opened a single course has 0% completion, not "excluded from
    // the average entirely". Averaging only over existing rows let a
    // handful of early adopters who'd each finished one course out of a
    // 500-member platform read as ~100% adoption instead of the true
    // fraction-of-a-percent. `count()` below issues a HEAD request (no rows
    // returned) rather than an expensive full cross-join.
    final progressRows = await _client.from('course_progress').select('progress');
    final progressSum = (progressRows as List).fold<int>(0, (sum, r) => sum + ((r as Map<String, dynamic>)['progress'] as int));
    final totalMembers = await _client.from('profiles').count().eq('role', 'member');
    final totalCourses = await _client.from('training_courses').count();
    final trainingCompletionPct = trainingCompletionPctFrom(progressSum: progressSum, totalMembers: totalMembers, totalCourses: totalCourses);

    // Same staff-only queue SchemeApplicationsReviewPage already surfaces —
    // just the count, not the full joined row set that page needs.
    final pendingRows = await _client.from('scheme_applications').select('id').inFilter('status', ['applied', 'under_review']);
    final pendingReviewCount = (pendingRows as List).length;

    // Real recent rows across a few core tables, merged and sorted by their
    // own `created_at` — replaces the previous static 3-row placeholder
    // feed with static relative timestamps that never changed.
    final recentUsers = await _client.from('profiles').select('name, created_at').order('created_at', ascending: false).limit(5);
    final recentShgs = await _client.from('shgs').select('name, created_at').order('created_at', ascending: false).limit(5);
    final recentDocs = await _client.from('shg_documents').select('name, created_at').order('created_at', ascending: false).limit(5);
    final activity = <AdminActivityItem>[
      for (final r in recentUsers as List) AdminActivityItem(kind: AdminActivityKind.newUser, subjectName: (r as Map<String, dynamic>)['name'] as String, occurredAt: DateTime.parse(r['created_at'] as String)),
      for (final r in recentShgs as List) AdminActivityItem(kind: AdminActivityKind.newShg, subjectName: (r as Map<String, dynamic>)['name'] as String, occurredAt: DateTime.parse(r['created_at'] as String)),
      for (final r in recentDocs as List) AdminActivityItem(kind: AdminActivityKind.document, subjectName: (r as Map<String, dynamic>)['name'] as String, occurredAt: DateTime.parse(r['created_at'] as String)),
    ]..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    return AdminDashboardStats(trainingCompletionPct: trainingCompletionPct, pendingReviewCount: pendingReviewCount, recentActivity: activity.take(5).toList());
  }

  /// Pure arithmetic for the live-mode training-completion percentage,
  /// factored out of [fetchDashboardStats] so it's directly unit-testable
  /// without a live Supabase project (no live DB is reachable from this
  /// dev environment — see
  /// test/repositories/admin_dashboard_stats_repository_test.dart). The
  /// denominator is every (member × course) pair that could exist, not just
  /// the `course_progress` rows that already do: a handful of members who
  /// have each finished one course out of a much larger, mostly-untouched
  /// platform must read as a small adoption percentage, not ~100%.
  static int trainingCompletionPctFrom({required int progressSum, required int totalMembers, required int totalCourses}) {
    final totalPairs = totalMembers * totalCourses;
    return totalPairs == 0 ? 0 : (progressSum / totalPairs).round();
  }

  // Mirrors ShgRepository._parseMockDate (kept as a separate copy rather
  // than a shared import to avoid a new cross-repository dependency
  // existing only for this one demo-mode date parse — same call this
  // repository already made for AdminRepository.debugMembersOverride's own
  // doc comment).
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
