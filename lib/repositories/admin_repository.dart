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
          .map((m) => Profile(id: m.id, name: m.name, mobile: m.mobile, role: _locallyUpdatedRoles[m.id] ?? _mockRoleMap[m.role] ?? 'member', shgId: _locallyAssignedShgs[m.id] ?? 'demo-shg', village: null, isActive: _locallyActive[m.id] ?? true))
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
  static final Map<String, bool> _locallyActive = {};

  /// Admin-only (`profiles_update_self_or_admin`'s WITH CHECK, migration
  /// 0083) — deactivating collapses the account's `current_role()`/
  /// `current_shg_id()`/`is_staff()`/`is_leader_or_staff()` to null/false
  /// server-side, blocking most further reads/writes regardless of what the
  /// client does; see that migration's own doc comment for the documented
  /// (non-silent) scope limit on bare `member_id = auth.uid()` branches.
  Future<void> setActive(String userId, bool active) async {
    if (!_live) {
      _locallyActive[userId] = active;
      return;
    }
    await _client.from('profiles').update({'is_active': active, 'deactivated_at': active ? null : DateTime.now().toIso8601String()}).eq('id', userId);
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
    // Was an unconditional `[]` — unlike `ProfileSetupPage._pickShg()`
    // (which special-cases demo mode with a fixed SHG before ever
    // reaching a search sheet), this method had no demo-mode branch at
    // all, so "Assign SHG" on any unlinked demo user always showed an
    // empty "No SHGs found" sheet regardless of query, with zero
    // explanation, even though `_locallyAssignedShgs` demo-tracking is
    // otherwise fully wired to receive a selection.
    if (!_live) {
      const demoShg = ShgSearchResult(
        id: 'demo-shg',
        name: mock_shg.ShgInfo.name,
        village: mock_shg.ShgInfo.village,
        mandal: mock_shg.ShgInfo.mandal,
        district: mock_shg.ShgInfo.district,
        grade: mock_shg.ShgInfo.grade,
      );
      return query.trim().isEmpty || demoShg.name.toLowerCase().contains(query.trim().toLowerCase()) ? [demoShg] : const [];
    }
    final builder = _client.from('shg_directory').select();
    // Same fix as ProfileRepository.searchShgs — an unordered query gives no
    // guarantee of stable result ordering between calls.
    final rows = await (query.trim().isEmpty ? builder.order('name').limit(20) : builder.ilike('name', '%${query.trim()}%').order('name').limit(20));
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
    // `.count()` (a PostgREST HEAD request returning just a number, no
    // rows) rather than `select('id')` + `.length` — the previous version
    // pulled every row's id over the wire on every single page load, with
    // no upper bound, for exactly the tables (`savings_entries`, `loans`)
    // expected to grow fastest as the platform scales. Matches the pattern
    // `fetchTrainingCompletionPct` (just above) already uses correctly.
    final totalUsers = await _client.from('profiles').count();
    final totalShgs = await _client.from('shgs').count();
    final totalSavingsEntries = await _client.from('savings_entries').count();
    final totalLoans = await _client.from('loans').count();
    final pendingLoans = await _client.from('loans').count().eq('status', 'pending');
    return SystemHealth(
      totalUsers: totalUsers,
      totalShgs: totalShgs,
      totalSavingsEntries: totalSavingsEntries,
      totalLoans: totalLoans,
      pendingLoans: pendingLoans,
      checkedAt: DateTime.now(),
    );
  }

  /// Average training-completion percentage platform-wide, split out of
  /// [fetchDashboardStats] specifically so a CRP/CLF dashboard can show
  /// just this one stat — round 135's SRS.md gap note found `is_staff()`
  /// already made this genuinely staff-wide (not admin-only) at the RLS
  /// layer, but the only call site was `fetchDashboardStats`, which
  /// non-trivially bundles this together with an admin-flavored
  /// pendingReviewCount/recentActivity feed. Building "just the stat" is
  /// what that round explicitly deferred; this is that follow-up.
  ///
  /// Demo mode routes through `TrainingRepository` itself (not the static
  /// mock catalog directly) so it reflects whatever that repository's own
  /// mutable demo-mode state currently says
  /// (`TrainingRepository._locallyCertified` via `markCertified()`) —
  /// reading the const mock list directly would go stale the instant a
  /// demo user actually certified a course.
  ///
  /// Live mode: `is_staff()` lets this bypass `course_progress_select_
  /// related`'s normal member-scoped read (supabase/migrations/0037_
  /// select_scope_overexposure_fix.sql). The denominator is every
  /// (member × course) pair that could exist, not just the course_progress
  /// rows that already do — a member who has never opened a single course
  /// has 0% completion, not "excluded from the average entirely".
  /// Averaging only over existing rows let a handful of early adopters
  /// who'd each finished one course out of a 500-member platform read as
  /// ~100% adoption instead of the true fraction-of-a-percent. `count()`
  /// below issues a HEAD request (no rows returned) rather than an
  /// expensive full cross-join.
  Future<int> fetchTrainingCompletionPct() async {
    if (!_live) {
      final progress = await TrainingRepository().fetchMyProgress(null);
      return progress.isEmpty ? 0 : (progress.values.map((c) => c.progress).reduce((a, b) => a + b) / progress.length).round();
    }
    // A member's own `progress` write is entirely self-reported (RLS lets
    // them set it to 100 unconditionally — `course_progress_write_self_or_
    // staff`, 0037) and never actually proves they passed the course's
    // quiz. `submit_quiz_attempt` (0051) is the only path that can ever set
    // `certified = true`, so for any course that HAS quiz questions, count
    // completion by `certified`, not `progress` — otherwise this
    // federation-facing adoption stat could be inflated by members who
    // opened a course and immediately self-marked 100% without answering a
    // single question correctly. A course with NO quiz questions at all has
    // no server-side way to verify completion in the first place, so
    // `progress` is still the only signal available there and is trusted
    // as before.
    // `is_active` (migration 0083) — a deactivated member's own
    // course_progress rows must be excluded from BOTH the numerator and
    // the denominator, not just one: filtering only `totalMembers` while
    // still summing every deactivated member's `progress`/`certified` into
    // `progressSum` would inflate this stat instead of correcting it.
    final activeMemberIds = (await _client.from('profiles').select('id').eq('role', 'member').eq('is_active', true) as List).map((r) => (r as Map<String, dynamic>)['id'] as String).toSet();
    final quizzedCourseRows = await _client.from('quiz_questions').select('course_id');
    final quizzedCourseIds = (quizzedCourseRows as List).map((r) => (r as Map<String, dynamic>)['course_id'] as String).toSet();
    final progressRows = await _client.from('course_progress').select('member_id, course_id, progress, certified');
    final progressSum = (progressRows as List).fold<int>(0, (sum, r) {
      final map = r as Map<String, dynamic>;
      if (!activeMemberIds.contains(map['member_id'] as String)) return sum;
      final hasQuiz = quizzedCourseIds.contains(map['course_id'] as String);
      return sum + (hasQuiz ? ((map['certified'] as bool) ? 100 : 0) : map['progress'] as int);
    });
    final totalMembers = activeMemberIds.length;
    final totalCourses = await _client.from('training_courses').count();
    return trainingCompletionPctFrom(progressSum: progressSum, totalMembers: totalMembers, totalCourses: totalCourses);
  }

  /// Backs the Admin dashboard's "Training Completion" stat, "pending
  /// verification" banner, and "Recent System Activity" feed — all three
  /// used to be static constants in `admin_dashboard.dart` that never
  /// changed no matter what happened on the platform (see
  /// [AdminDashboardStats]'s doc comment). System uptime is deliberately
  /// not computed here — see the same doc comment for why that one figure
  /// stays a labeled placeholder on the dashboard itself.
  ///
  /// [viewerId] excludes the caller's own scheme application from
  /// [AdminDashboardStats.pendingReviewCount] — mirroring
  /// `SchemeApplicationsReviewPage`'s own identical `a.memberId != myId`
  /// filter on the queue this banner links to. Before this parameter
  /// existed, a staff account who is also a real SHG member with her own
  /// pending application saw this banner overcount by exactly one: RLS
  /// (`scheme_applications_update_staff`'s `member_id <> auth.uid()`)
  /// already blocked her from deciding it, so tapping through to the queue
  /// showed one fewer actionable row than this count claimed.
  Future<AdminDashboardStats> fetchDashboardStats(String? viewerId) async {
    if (!_live) {
      final trainingCompletionPct = await fetchTrainingCompletionPct();
      final pendingApps = await SchemeRepository().fetchPendingApplications();
      final pendingReviewCount = pendingApps.where((a) => a.memberId != viewerId).length;

      // "Recent activity" assembled the same way the live branch below
      // does — real (if fixed/demo) rows from a couple of different mock
      // tables, merged and sorted by their own date, not a disconnected
      // fabricated list.
      final docActivity = mock_shg.documents.map((d) => AdminActivityItem(kind: AdminActivityKind.document, subjectName: d.name, occurredAt: _parseMockDate(d.date)));
      final memberActivity = (debugMembersOverride ?? mock.members).map((m) => AdminActivityItem(kind: AdminActivityKind.newUser, subjectName: m.name, occurredAt: _parseMockDate(m.joiningDate)));
      final activity = [...docActivity, ...memberActivity]..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

      return AdminDashboardStats(trainingCompletionPct: trainingCompletionPct, pendingReviewCount: pendingReviewCount, recentActivity: activity.take(5).toList());
    }

    final trainingCompletionPct = await fetchTrainingCompletionPct();

    // Same staff-only queue SchemeApplicationsReviewPage already surfaces —
    // just the count, not the full joined row set that page needs. Also
    // applies that page's own member_id != viewerId filter (see this
    // method's doc comment) so the two never visibly disagree.
    final pendingRows = await _client.from('scheme_applications').select('id, member_id').inFilter('status', ['applied', 'under_review']);
    final pendingReviewCount = (pendingRows as List).where((r) => (r as Map<String, dynamic>)['member_id'] != viewerId).length;

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

  // 10-minute cron cadence (migration 0044) — a heartbeat is considered
  // stale/unhealthy once more than double that window has elapsed since the
  // last recorded one, allowing for ordinary cron/network jitter without
  // flagging a false negative on every dashboard load.
  static const _heartbeatHealthyWithin = Duration(minutes: 20);

  /// Backs the Admin dashboard's "System Uptime" stat — replaces what used
  /// to be a hardcoded `'N/A'` constant (`admin_dashboard.dart`'s
  /// `_systemUptime`) with a real, if deliberately narrow, signal: whether
  /// this project's own pg_cron scheduler is still alive (see
  /// [SystemHeartbeatStatus]'s doc comment for exactly what this does and
  /// does not claim to measure).
  Future<SystemHeartbeatStatus> fetchSystemHeartbeatStatus() async {
    if (!_live) {
      // Demo mode has no real pg_cron to observe — shows a synthetic
      // "just now" healthy heartbeat, consistent with how [fetchSystemHealth]
      // already mixes in illustrative demo-mode figures elsewhere on this
      // same dashboard rather than showing a real service's absence.
      return SystemHeartbeatStatus(lastHeartbeatAt: DateTime.now(), healthy: true);
    }
    final rows = await _client.from('system_heartbeats').select('recorded_at').order('recorded_at', ascending: false).limit(1);
    final list = rows as List;
    if (list.isEmpty) {
      // Migration 0044 not yet deployed, or pg_cron hasn't fired its first
      // heartbeat yet since deployment — an honest "unknown/unhealthy"
      // state, not a fabricated pass.
      return const SystemHeartbeatStatus(lastHeartbeatAt: null, healthy: false);
    }
    final lastHeartbeatAt = DateTime.parse((list.first as Map<String, dynamic>)['recorded_at'] as String);
    final healthy = DateTime.now().difference(lastHeartbeatAt) < _heartbeatHealthyWithin;
    return SystemHeartbeatStatus(lastHeartbeatAt: lastHeartbeatAt, healthy: healthy);
  }

  /// Backs a staff-visible "AI Advisor moderation blocks (7 days)" stat on
  /// the Admin Monitoring page — real counts from `ai_advisor_logs`'
  /// `blocked`/`block_reason` columns (migration 0044), not a fabricated
  /// figure. See [AiAdvisorModerationStats]'s doc comment for what gap this
  /// closes.
  Future<AiAdvisorModerationStats> fetchAiAdvisorModerationStats() async {
    if (!_live) {
      // Demo mode's mock AI advisor service never actually runs content
      // moderation (see MockAiAdvisorService) — there is nothing real to
      // count, so this honestly reports zero rather than fabricating
      // illustrative abuse activity.
      return const AiAdvisorModerationStats(blockedCount7d: 0, distinctMembersFlagged7d: 0);
    }
    final since = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
    final rows = await _client.from('ai_advisor_logs').select('member_id').eq('blocked', true).gte('created_at', since);
    final list = rows as List;
    final distinctMembers = list.map((r) => (r as Map<String, dynamic>)['member_id'] as String).toSet().length;
    return AiAdvisorModerationStats(blockedCount7d: list.length, distinctMembersFlagged7d: distinctMembers);
  }

  /// Backs `AdminAuditLogPage` — the read side of the triggers migration
  /// 0082 wired up (role/SHG-grade/livelihood-override/loan-decision
  /// changes). Demo mode has no real audit trail to show (nothing in this
  /// app's mock data model represents a privileged-action log), so it
  /// returns empty rather than fabricating illustrative rows. Keyset
  /// paginated on `(created_at desc, id desc)` — `id` is an arbitrary but
  /// stable tiebreaker for the rare case two rows share the same
  /// microsecond timestamp, same composite-cursor shape as
  /// FinancialRepository's ledger pagination.
  Future<PagedResult<AuditLogEntry>> fetchAuditLog({DateTime? afterCreatedAt, String? afterId, int pageSize = 50}) async {
    if (!_live) return const PagedResult(items: [], hasMore: false);
    var builder = _client.from('audit_log').select('*, actor:profiles!actor_id(name)');
    if (afterCreatedAt != null && afterId != null) {
      final c = afterCreatedAt.toIso8601String();
      builder = builder.or('created_at.lt.$c,and(created_at.eq.$c,id.lt.$afterId)');
    }
    final rows = await builder.order('created_at', ascending: false).order('id', ascending: false).limit(pageSize + 1);
    final list = (rows as List).map((r) => AuditLogEntry.fromMap(r as Map<String, dynamic>)).toList();
    final hasMore = list.length > pageSize;
    return PagedResult(items: hasMore ? list.sublist(0, pageSize) : list, hasMore: hasMore);
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
