/// A snapshot of basic platform counts. No real infra-monitoring service
/// (uptime, error rates, latency) is wired yet — that would need a
/// dedicated Edge Function or external monitoring integration. This is a
/// documented placeholder computed from table row counts instead.
class SystemHealth {
  final int totalUsers;
  final int totalShgs;
  final int totalSavingsEntries;
  final int totalLoans;
  final int pendingLoans;
  final DateTime checkedAt;

  const SystemHealth({
    required this.totalUsers,
    required this.totalShgs,
    required this.totalSavingsEntries,
    required this.totalLoans,
    required this.pendingLoans,
    required this.checkedAt,
  });
}

/// What kind of real record a [AdminActivityItem] was derived from — lets
/// the page (not this model) pick a badge tone/icon per kind, the same
/// separation `Course`/`Scheme` already keep from `BadgeTone`.
enum AdminActivityKind { newUser, newShg, document }

/// One row in the Admin dashboard's "Recent System Activity" feed — a real
/// recently-created row (a new profile, a new SHG, an uploaded document),
/// not a static placeholder. See `AdminRepository.fetchDashboardStats`.
class AdminActivityItem {
  final AdminActivityKind kind;
  // The interpolated part only (a document/member/user/SHG name) — kept as
  // raw data rather than a pre-formatted English sentence so the page can
  // build the actual display message through AppLocalizations, keyed off
  // [kind], instead of baking an un-localizable string into the repository
  // layer.
  final String subjectName;
  final DateTime occurredAt;
  const AdminActivityItem({required this.kind, required this.subjectName, required this.occurredAt});
}

/// Whether this app's own scheduled-job infrastructure (pg_cron) is still
/// alive — computed from `public.system_heartbeats`, a row written every 10
/// minutes by `record_system_heartbeat()` (migration 0044). Deliberately
/// narrow in scope: this answers "is our own cron scheduler still running",
/// not "what is the uptime/latency/error-rate of every service in the
/// stack" — that broader claim would need real external APM this codebase
/// doesn't have wired up, the same honest-scoping this app already applies
/// to [SystemHealth]. Replaces the Admin dashboard's previous hardcoded
/// `'N/A'` system-uptime placeholder with a real, if narrowly-scoped,
/// signal.
class SystemHeartbeatStatus {
  final DateTime? lastHeartbeatAt;
  final bool healthy;
  const SystemHeartbeatStatus({required this.lastHeartbeatAt, required this.healthy});
}

/// Staff-visible abuse-review signal for the AI Advisor chat: how many
/// requests content moderation (the regex pre-filter or the Llama Guard ML
/// classifier — see `supabase/functions/ai-advisor-proxy`) rejected in the
/// last 7 days, and how many distinct members those attempts came from.
/// Closes docs/AI_MODULES.md §6's disclosed "no anomaly/abuse monitoring on
/// the logs" gap — a rejected attempt used to leave no trace anywhere at
/// all (see migration 0044).
class AiAdvisorModerationStats {
  final int blockedCount7d;
  final int distinctMembersFlagged7d;
  const AiAdvisorModerationStats({required this.blockedCount7d, required this.distinctMembersFlagged7d});
}

/// Real, computed figures for the Admin dashboard that used to be static
/// constants in `admin_dashboard.dart` (`_trainingCompletion`,
/// `_pendingVerificationCount`, `_recentActivity`) with no backing data at
/// all — they never changed no matter what actually happened on the
/// platform. System uptime is deliberately NOT part of this class — it's
/// now backed by the separate [SystemHeartbeatStatus] (`fetchSystemHeartbeatStatus`)
/// instead of being folded into this bulk stats fetch, since it comes from
/// a different table with a different real-time freshness requirement.
class AdminDashboardStats {
  /// Average `course_progress.progress` across every member/course pair
  /// platform-wide — including pairs with no `course_progress` row at all,
  /// which contribute 0 rather than being excluded from the average (0 when
  /// there are no members or no courses yet) — rounded to the nearest
  /// percent.
  final int trainingCompletionPct;

  /// Count of `scheme_applications` rows still awaiting a staff decision
  /// (`applied` or `under_review`) — the same real review queue
  /// `SchemeApplicationsReviewPage`/`SchemeRepository.fetchPendingApplications`
  /// already lets staff act on.
  final int pendingReviewCount;

  /// Most recent real activity across a few core tables, newest first.
  final List<AdminActivityItem> recentActivity;

  const AdminDashboardStats({
    required this.trainingCompletionPct,
    required this.pendingReviewCount,
    required this.recentActivity,
  });
}
