/// Platform-wide KPIs, aggregated across every SHG. Backed by
/// `public.analytics_kpis` in spirit (metric/value/period rows scoped by
/// `shg_id`) but currently computed client-side — see [AnalyticsRepository].
class PlatformKpis {
  final int totalShgs;
  final int activeMembers;
  final num totalSavings;
  final num loansDisbursed;
  final double recoveryRatePct;

  const PlatformKpis({
    required this.totalShgs,
    required this.activeMembers,
    required this.totalSavings,
    required this.loansDisbursed,
    required this.recoveryRatePct,
  });
}

/// One SHG's monitoring summary — health score is currently its average
/// completed-meeting attendance rate (a real, defensible proxy metric until
/// `analytics_kpis` is populated server-side with a richer formula).
class ShgHealth {
  final String id;
  final String name;
  final String village;
  final String? grade;
  final int memberCount;
  final num totalSavings;
  final double healthScore;

  const ShgHealth({
    required this.id,
    required this.name,
    required this.village,
    this.grade,
    required this.memberCount,
    required this.totalSavings,
    required this.healthScore,
  });
}
