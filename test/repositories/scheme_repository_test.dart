import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/models/scheme.dart';
import 'package:shg_saathi/repositories/scheme_repository.dart';
import 'package:shg_saathi/services/supabase_service.dart';

/// Regression coverage for `SchemeRepository`'s structured
/// `EligibilityCriteria` plumbing (demo mode only — no live Supabase
/// project is reachable in this environment; see
/// `supabase/migrations/0040_scheme_eligibility_criteria.sql` for the
/// still-to-be-deployed live-mode column this mirrors).
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  group('fetchSchemes — demo-mode structured criteria', () {
    test('DAY-NRLM carries its declared requiresShgMembership + minShgAgeMonths criteria', () async {
      final schemes = await SchemeRepository().fetchSchemes();
      final dayNrlm = schemes.firstWhere((s) => s.id == 'sc1');
      expect(dayNrlm.criteria.requiresShgMembership, isTrue);
      expect(dayNrlm.criteria.minShgAgeMonths, 6);
      expect(dayNrlm.criteria.isEmpty, isFalse);
    });

    test('NRLM RF carries its declared minShgGrade criterion', () async {
      final schemes = await SchemeRepository().fetchSchemes();
      final nrlmRf = schemes.firstWhere((s) => s.id == 'sc5');
      expect(nrlmRf.criteria.requiresShgMembership, isTrue);
      expect(nrlmRf.criteria.minShgGrade, 'B');
    });

    test('PMEGP genuinely has no structured criteria (individual-entrepreneur scheme, not SHG-gated)', () async {
      final schemes = await SchemeRepository().fetchSchemes();
      final pmegp = schemes.firstWhere((s) => s.id == 'sc2');
      expect(pmegp.criteria.isEmpty, isTrue);
    });

    test('not every mock scheme is left with empty/default criteria', () async {
      final schemes = await SchemeRepository().fetchSchemes();
      expect(schemes.any((s) => !s.criteria.isEmpty), isTrue, reason: 'demo mode must actually demonstrate the structured rules engine, not leave every scheme criteria-less');
    });
  });

  group('createScheme / updateScheme — demo-mode criteria persistence', () {
    test('a newly created scheme keeps the structured criteria it was created with', () async {
      final repo = SchemeRepository();
      const criteria = EligibilityCriteria(requiresShgMembership: true, minShgAgeMonths: 18, minShgGrade: 'A');
      await repo.createScheme(name: '__TEST__ Created Scheme', criteria: criteria);

      final schemes = await repo.fetchSchemes();
      final created = schemes.firstWhere((s) => s.name == '__TEST__ Created Scheme');
      expect(created.criteria.requiresShgMembership, isTrue);
      expect(created.criteria.minShgAgeMonths, 18);
      expect(created.criteria.minShgGrade, 'A');
    });

    test('updateScheme overwrites the stored criteria with the newly supplied ones', () async {
      final repo = SchemeRepository();
      await repo.createScheme(name: '__TEST__ Editable Scheme', criteria: const EligibilityCriteria(requiresShgMembership: true));

      final beforeEdit = (await repo.fetchSchemes()).firstWhere((s) => s.name == '__TEST__ Editable Scheme');
      await repo.updateScheme(
        beforeEdit.id,
        name: beforeEdit.name,
        fullName: beforeEdit.fullName,
        agency: beforeEdit.agency,
        benefit: beforeEdit.benefit,
        criteria: const EligibilityCriteria(minShgGrade: 'C'),
      );

      final afterEdit = (await repo.fetchSchemes()).firstWhere((s) => s.id == beforeEdit.id);
      expect(afterEdit.criteria.requiresShgMembership, isFalse, reason: 'updateScheme must overwrite, not merge with, the previous criteria');
      expect(afterEdit.criteria.minShgGrade, 'C');
    });
  });
}
