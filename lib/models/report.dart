/// Shape mirrors what `public.report_snapshots.data` will eventually hold
/// once an Edge Function generates these server-side. Until then, the
/// repository computes the same shape on-the-fly from live tables.
class MemberReport {
  final num totalSavings;
  final int savingsEntryCount;
  final num totalOutstanding;
  final int activeLoanCount;
  final int meetingsAttended;
  final int meetingsTotal;
  final String period;

  const MemberReport({
    required this.totalSavings,
    required this.savingsEntryCount,
    required this.totalOutstanding,
    required this.activeLoanCount,
    required this.meetingsAttended,
    required this.meetingsTotal,
    required this.period,
  });

  double get attendancePct => meetingsTotal == 0 ? 0 : (meetingsAttended / meetingsTotal) * 100;
}

class ShgReportData {
  final int memberCount;
  final num totalSavings;
  final num totalOutstanding;
  final int activeLoanCount;
  final double avgAttendancePct;
  final String period;

  const ShgReportData({
    required this.memberCount,
    required this.totalSavings,
    required this.totalOutstanding,
    required this.activeLoanCount,
    required this.avgAttendancePct,
    required this.period,
  });
}

class VillageShgGroup {
  final String village;
  final int shgCount;
  final num totalSavings;
  const VillageShgGroup({required this.village, required this.shgCount, required this.totalSavings});
}

class FederationReportData {
  final int shgCount;
  final int memberCount;
  final num totalSavings;
  final num totalOutstanding;
  final String period;

  const FederationReportData({
    required this.shgCount,
    required this.memberCount,
    required this.totalSavings,
    required this.totalOutstanding,
    required this.period,
  });
}
