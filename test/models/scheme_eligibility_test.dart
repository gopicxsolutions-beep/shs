import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/models/scheme.dart';

/// Regression coverage for `evaluateSchemeEligibility` — the structured
/// rules engine that replaced the Government Schemes eligibility checker's
/// old free-text keyword-matching heuristic (fuzzy-matching yes/no toggle
/// answers against substrings of `Scheme.eligibility` prose). This function
/// is pure (no network/database dependency, no fetching of its own — it
/// takes caller-resolved member facts), so every branch is covered directly
/// here rather than only indirectly through a widget test.
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  const scheme = Scheme(id: 's1', name: 'Test Scheme');

  group('EligibilityCriteria', () {
    test('isEmpty is true only when no structured criterion is set', () {
      expect(const EligibilityCriteria().isEmpty, isTrue);
      expect(const EligibilityCriteria(requiresShgMembership: true).isEmpty, isFalse);
      expect(const EligibilityCriteria(minShgAgeMonths: 6).isEmpty, isFalse);
      expect(const EligibilityCriteria(minShgGrade: 'B').isEmpty, isFalse);
    });

    test('toMap/fromMap round-trip preserves every field', () {
      const criteria = EligibilityCriteria(requiresShgMembership: true, minShgAgeMonths: 12, minShgGrade: 'B+');
      final roundTripped = EligibilityCriteria.fromMap(criteria.toMap());
      expect(roundTripped.requiresShgMembership, isTrue);
      expect(roundTripped.minShgAgeMonths, 12);
      expect(roundTripped.minShgGrade, 'B+');
    });

    test('fromMap defaults to empty criteria for a null or empty map (older/plain catalog rows)', () {
      expect(EligibilityCriteria.fromMap(null).isEmpty, isTrue);
      expect(EligibilityCriteria.fromMap({}).isEmpty, isTrue);
    });

    test('fromMap tolerates a numeric (not strictly int) JSON value for min_shg_age_months', () {
      // Postgrest/JSON decoding can hand back a `num` rather than a Dart
      // `int` literal for a jsonb numeric value — this must not throw.
      final criteria = EligibilityCriteria.fromMap({'min_shg_age_months': 6.0});
      expect(criteria.minShgAgeMonths, 6);
    });
  });

  group('evaluateSchemeEligibility — no structured criteria', () {
    test('a scheme with empty criteria produces zero checks (not a false "always eligible" claim)', () {
      final result = evaluateSchemeEligibility(scheme, l10n: l10n, hasShgMembership: false);
      expect(result.checks, isEmpty);
      // vacuously true (every element of an empty list satisfies `met`) —
      // the page itself must treat an empty checks list as "nothing to
      // show", not surface this flag as a claim of confirmed eligibility.
      expect(result.isEligible, isTrue);
    });
  });

  group('evaluateSchemeEligibility — requiresShgMembership', () {
    const criteria = EligibilityCriteria(requiresShgMembership: true);
    final gated = Scheme(id: 's2', name: 'Gated', criteria: criteria);

    test('met when the member has an SHG', () {
      final result = evaluateSchemeEligibility(gated, l10n: l10n, hasShgMembership: true);
      expect(result.isEligible, isTrue);
      expect(result.checks, hasLength(1));
      expect(result.checks.single.met, isTrue);
      expect(result.checks.single.label, contains('you are linked to an SHG'));
    });

    test('not met, with a specific reason, when the member has no SHG', () {
      final result = evaluateSchemeEligibility(gated, l10n: l10n, hasShgMembership: false);
      expect(result.isEligible, isFalse);
      expect(result.checks.single.met, isFalse);
      expect(result.checks.single.label, 'Requires SHG membership — you are not linked to an SHG');
    });
  });

  group('evaluateSchemeEligibility — minShgAgeMonths', () {
    const criteria = EligibilityCriteria(requiresShgMembership: true, minShgAgeMonths: 6);
    final aged = Scheme(id: 's3', name: 'Aged', criteria: criteria);

    test('met when the SHG is old enough', () {
      final result = evaluateSchemeEligibility(aged, l10n: l10n, hasShgMembership: true, shgAgeMonths: 145);
      expect(result.isEligible, isTrue);
      expect(result.checks.every((c) => c.met), isTrue);
    });

    test('exactly at the threshold counts as met (>=, not >)', () {
      final result = evaluateSchemeEligibility(aged, l10n: l10n, hasShgMembership: true, shgAgeMonths: 6);
      final ageCheck = result.checks.firstWhere((c) => c.label.contains('registered'));
      expect(ageCheck.met, isTrue);
    });

    test('not met when the SHG is too new, with the actual age in the reason', () {
      final result = evaluateSchemeEligibility(aged, l10n: l10n, hasShgMembership: true, shgAgeMonths: 2);
      expect(result.isEligible, isFalse);
      final ageCheck = result.checks.firstWhere((c) => c.label.contains('registered'));
      expect(ageCheck.met, isFalse);
      expect(ageCheck.label, contains('yours is registered 2 months'));
    });

    test('not met (fail-safe) when the SHG\'s registration date is unknown', () {
      final result = evaluateSchemeEligibility(aged, l10n: l10n, hasShgMembership: true, shgAgeMonths: null);
      final ageCheck = result.checks.firstWhere((c) => c.label.contains('registered'));
      expect(ageCheck.met, isFalse);
      expect(ageCheck.label, contains('isn\'t on record'));
    });

    test('not met when the member has no SHG at all, regardless of any stale age value', () {
      final result = evaluateSchemeEligibility(aged, l10n: l10n, hasShgMembership: false, shgAgeMonths: 999);
      expect(result.isEligible, isFalse);
      expect(result.checks.every((c) => c.met), isFalse);
    });
  });

  group('evaluateSchemeEligibility — minShgGrade', () {
    const criteria = EligibilityCriteria(requiresShgMembership: true, minShgGrade: 'B');
    final graded = Scheme(id: 's4', name: 'Graded', criteria: criteria);

    test('a better-than-required grade meets the bar (A+ meets a B-or-above requirement)', () {
      final result = evaluateSchemeEligibility(graded, l10n: l10n, hasShgMembership: true, shgGrade: 'A+');
      expect(result.isEligible, isTrue);
    });

    test('exactly the required grade meets the bar', () {
      final result = evaluateSchemeEligibility(graded, l10n: l10n, hasShgMembership: true, shgGrade: 'B');
      expect(result.isEligible, isTrue);
    });

    test('a worse-than-required grade fails, with the actual grade in the reason', () {
      final result = evaluateSchemeEligibility(graded, l10n: l10n, hasShgMembership: true, shgGrade: 'C');
      expect(result.isEligible, isFalse);
      final gradeCheck = result.checks.firstWhere((c) => c.label.contains('grade'));
      expect(gradeCheck.label, contains('yours is graded C'));
    });

    test('not met (fail-safe) when the SHG has no recorded grade', () {
      final result = evaluateSchemeEligibility(graded, l10n: l10n, hasShgMembership: true, shgGrade: null);
      expect(result.isEligible, isFalse);
      final gradeCheck = result.checks.firstWhere((c) => c.label.contains('grade'));
      expect(gradeCheck.label, contains('isn\'t on record'));
    });

    test('not met (fail-safe) for an unrecognized grade string', () {
      final result = evaluateSchemeEligibility(graded, l10n: l10n, hasShgMembership: true, shgGrade: 'Z');
      expect(result.isEligible, isFalse);
    });
  });

  group('evaluateSchemeEligibility — multiple criteria', () {
    test('overall eligible only when every declared criterion is met', () {
      const criteria = EligibilityCriteria(requiresShgMembership: true, minShgAgeMonths: 6, minShgGrade: 'B');
      final multi = Scheme(id: 's5', name: 'Multi', criteria: criteria);

      final allMet = evaluateSchemeEligibility(multi, l10n: l10n, hasShgMembership: true, shgAgeMonths: 24, shgGrade: 'A');
      expect(allMet.isEligible, isTrue);
      expect(allMet.checks, hasLength(3));

      final oneUnmet = evaluateSchemeEligibility(multi, l10n: l10n, hasShgMembership: true, shgAgeMonths: 24, shgGrade: 'C');
      expect(oneUnmet.isEligible, isFalse);
      expect(oneUnmet.checks.where((c) => c.met), hasLength(2));
      expect(oneUnmet.checks.where((c) => !c.met), hasLength(1));
    });
  });
}
