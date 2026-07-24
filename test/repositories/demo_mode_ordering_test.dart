import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/repositories/loan_repository.dart';
import 'package:shg_saathi/repositories/scheme_repository.dart';
import 'package:shg_saathi/services/supabase_service.dart';

/// Regression coverage for demo-vs-live ordering consistency. Several
/// repositories apply an explicit `.order(...)` on the live Supabase query
/// but previously left the demo-mode mock-data path in raw file-declaration
/// order — so the UI showed a different item order purely based on whether
/// Supabase happened to be configured, with no change in the calling page.
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  test('LoanRepository demo mode returns loans newest-first, matching the live order(created_at desc)', () async {
    final loans = await LoanRepository().fetchForMember(null);
    expect(loans, isNotEmpty);
    // lib/data/loans.dart declares loans oldest-disbursed-first with the
    // still-pending applications (no disbursedOn) last; newest-first means
    // those pending applications should now come first.
    for (var i = 0; i < loans.length - 1; i++) {
      final a = loans[i].disbursedOn;
      final b = loans[i + 1].disbursedOn;
      if (a == null || b == null) continue;
      expect(a.isAfter(b) || a.isAtSameMomentAs(b), isTrue, reason: 'loan at $i (disbursed $a) should not be older than loan at ${i + 1} (disbursed $b)');
    }
  });

  test('SchemeRepository demo mode returns schemes ascending by deadline, with no-deadline schemes last', () async {
    final schemes = await SchemeRepository().fetchSchemes();
    expect(schemes, isNotEmpty);
    final withDeadline = schemes.where((s) => s.deadline != null).toList();
    for (var i = 0; i < withDeadline.length - 1; i++) {
      expect(
        withDeadline[i].deadline!.isBefore(withDeadline[i + 1].deadline!) || withDeadline[i].deadline!.isAtSameMomentAs(withDeadline[i + 1].deadline!),
        isTrue,
        reason: 'scheme deadlines must be ascending',
      );
    }
    // Every scheme with a deadline must be ordered before every scheme
    // without one (NULLS LAST, matching the live order('deadline') query).
    final lastDeadlineIndex = schemes.lastIndexWhere((s) => s.deadline != null);
    final firstNullIndex = schemes.indexWhere((s) => s.deadline == null);
    if (lastDeadlineIndex != -1 && firstNullIndex != -1) {
      expect(lastDeadlineIndex, lessThan(firstNullIndex));
    }
  });
}
