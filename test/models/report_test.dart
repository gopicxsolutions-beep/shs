import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/models/report.dart';

/// Regression coverage for `MemberReport.attendancePct` — a pure getter
/// (`lib/models/report.dart`) that turns a member's raw
/// meetingsAttended/meetingsTotal counts into the percentage shown on the
/// member dashboard's "Attendance" stat and the Member Report page.
///
/// Traced by hand and confirmed correct: `meetingsTotal == 0 ? 0 :
/// (meetingsAttended / meetingsTotal) * 100`. The interesting part is the
/// explicit `meetingsTotal == 0` guard — without it, a brand-new SHG with
/// zero completed meetings would divide by zero and produce `NaN`/`Infinity`
/// instead of a sane 0%. This directly matters this session: rounds
/// touching `ReportRepository.fetchMemberReport`/`fetchShgReport` document
/// that `meetingsTotal` really can legitimately be 0 (every meeting still
/// upcoming), so this guard is load-bearing, not defensive-only. No bug
/// found here — this is regression protection for logic already correct.
void main() {
  MemberReport reportWith({required int attended, required int total}) => MemberReport(
        totalSavings: 0,
        savingsEntryCount: 0,
        totalOutstanding: 0,
        activeLoanCount: 0,
        meetingsAttended: attended,
        meetingsTotal: total,
        period: 'All time',
      );

  group('MemberReport.attendancePct', () {
    test('zero total meetings returns 0, not NaN/Infinity (division-by-zero guard)', () {
      final report = reportWith(attended: 0, total: 0);
      expect(report.attendancePct, 0);
    });

    test('a stray non-zero attended count with zero total still returns 0 (guard wins regardless)', () {
      // Shouldn't happen with real data (can't attend more meetings than
      // exist), but the guard checks meetingsTotal first regardless of
      // meetingsAttended, so this must not slip through and divide by zero.
      final report = reportWith(attended: 2, total: 0);
      expect(report.attendancePct, 0);
    });

    test('perfect attendance is 100%', () {
      final report = reportWith(attended: 4, total: 4);
      expect(report.attendancePct, 100);
    });

    test('zero attendance out of a non-zero total is 0%', () {
      final report = reportWith(attended: 0, total: 5);
      expect(report.attendancePct, 0);
    });

    test('partial attendance computes the correct percentage', () {
      final report = reportWith(attended: 3, total: 4);
      expect(report.attendancePct, 75);
    });

    test('a non-terminating fraction is not rounded away', () {
      final report = reportWith(attended: 1, total: 3);
      expect(report.attendancePct, closeTo(33.333, 0.001));
    });
  });
}
