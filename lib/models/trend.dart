/// One point in a monthly trend series (Savings/Loan/Revenue/Attendance
/// Trends on the Analytics dashboard, and the Federation "Savings Growth"
/// report) — see [TrendRepository].
class MonthlyPoint {
  final String month; // e.g. "Jan", "Feb" — short label for chart axes
  final num value;
  const MonthlyPoint(this.month, this.value);
}
