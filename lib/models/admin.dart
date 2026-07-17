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
