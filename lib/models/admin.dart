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

/// Real, computed figures for the Admin dashboard that used to be static
/// constants in `admin_dashboard.dart` (`_trainingCompletion`,
/// `_pendingVerificationCount`, `_recentActivity`) with no backing data at
/// all — they never changed no matter what actually happened on the
/// platform. System uptime is deliberately NOT part of this: a true
/// uptime/error-rate/latency figure needs a real APM or infra-monitoring
/// service this codebase doesn't have wired up (same documented gap as
/// [SystemHealth]), so that one stat stays a clearly-labeled placeholder on
/// the dashboard itself rather than being faked here.
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
