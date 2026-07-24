import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/repositories/shg_repository.dart';
import 'package:shg_saathi/services/supabase_service.dart';

/// Regression coverage for `ShgRepository.createShg()`/`updateShg()` actually
/// persisting `formation_date`/`grade` — the two facts the scheme
/// eligibility rules engine's `minShgAgeMonths`/`minShgGrade` criteria key
/// off of (`EligibilityCriteria` in lib/models/scheme.dart).
///
/// Before this fix, `createShg()` had no parameters for either field at all
/// (only name/village/mandal/district/state), and there was no
/// `updateShg()`/Edit-SHG UI anywhere in the app — so for every SHG
/// onboarded through this app in live mode, both facts stayed null forever
/// with zero in-app way to ever populate them, meaning a scheme requiring a
/// minimum SHG age or grade could never be satisfied by any real SHG.
///
/// Demo mode only — no live Supabase project is reachable in this
/// environment. The RLS side (whether admin/staff can actually write these
/// two columns live) is already covered by
/// `supabase/migrations/0013_self_service_write_check_gaps.sql`'s
/// `shgs_update_leader_or_staff` policy, whose `with check` clause grants
/// `is_staff()` an unrestricted branch (every column, including
/// `formation_date`/`grade`) — confirmed by reading that migration; no new
/// migration was needed for the write path itself.
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  group('createShg — formation date / grade persistence (demo mode)', () {
    test('a newly created SHG keeps the formation date and grade it was created with', () async {
      final repo = ShgRepository();
      final formationDate = DateTime(2020, 3, 15);
      await repo.createShg(
        name: '__TEST__ New SHG',
        village: 'Test Village',
        district: 'Test District',
        formationDate: formationDate,
        grade: 'B+',
      );

      final page = await repo.fetchAllShgs();
      final created = page.items.firstWhere((s) => s.name == '__TEST__ New SHG');
      expect(created.formationDate, formationDate);
      expect(created.grade, 'B+');
    });

    test('formation date and grade default to null when not supplied (both optional)', () async {
      final repo = ShgRepository();
      await repo.createShg(name: '__TEST__ Plain SHG');

      final page = await repo.fetchAllShgs();
      final created = page.items.firstWhere((s) => s.name == '__TEST__ Plain SHG');
      expect(created.formationDate, isNull);
      expect(created.grade, isNull);
    });
  });

  group('updateShg — the only in-app way to fix a missing formation date/grade after onboarding (demo mode)', () {
    test('editing a locally-created SHG persists its new formation date, grade, name, village and district', () async {
      final repo = ShgRepository();
      await repo.createShg(name: '__TEST__ Editable SHG', village: 'Old Village', district: 'Old District');
      final created = (await repo.fetchAllShgs()).items.firstWhere((s) => s.name == '__TEST__ Editable SHG');
      // Onboarded with no formation date/grade, same as every real SHG
      // created through this app before this fix existed — this is exactly
      // the scenario the bug report describes as permanently uncorrectable.
      expect(created.formationDate, isNull);
      expect(created.grade, isNull);

      final formationDate = DateTime(2018, 6, 1);
      await repo.updateShg(
        created.id,
        name: created.name,
        village: 'New Village',
        district: 'New District',
        formationDate: formationDate,
        grade: 'A',
      );

      final updated = (await repo.fetchAllShgs()).items.firstWhere((s) => s.id == created.id);
      expect(updated.formationDate, formationDate);
      expect(updated.grade, 'A');
      expect(updated.village, 'New Village');
      expect(updated.district, 'New District');
    });

    test('editing the fixed demo SHG persists a formation date/grade, visible via both fetchAllShgs and fetchShg', () async {
      final repo = ShgRepository();
      final demoShg = (await repo.fetchAllShgs()).items.firstWhere((s) => s.id == 'demo-shg');

      await repo.updateShg(
        demoShg.id,
        name: demoShg.name,
        village: demoShg.village,
        district: demoShg.district,
        formationDate: DateTime(2015, 1, 1),
        grade: 'C',
      );

      final afterAll = (await repo.fetchAllShgs()).items.firstWhere((s) => s.id == 'demo-shg');
      expect(afterAll.grade, 'C');
      expect(afterAll.formationDate, DateTime(2015, 1, 1));

      // fetchShg() is what member-facing pages (e.g. SchemeEligibilityPage)
      // actually call for "my SHG" — the edit must be visible there too,
      // not only on the Manage SHGs list, or it would look like the edit
      // silently didn't take.
      final afterFetch = await repo.fetchShg('demo-shg');
      expect(afterFetch?.grade, 'C');
      expect(afterFetch?.formationDate, DateTime(2015, 1, 1));
      // Fields this dialog doesn't manage (bank details in particular) must
      // survive the edit untouched, not get silently wiped.
      expect(afterFetch?.bankName, isNotNull);
      expect(afterFetch?.bankAccount, isNotNull);
    });

    test('editing never touches mandal/state, which the Add/Edit SHG dialogs do not expose', () async {
      final repo = ShgRepository();
      await repo.createShg(name: '__TEST__ Mandal SHG', mandal: 'Original Mandal', state: 'Original State');
      final created = (await repo.fetchAllShgs()).items.firstWhere((s) => s.name == '__TEST__ Mandal SHG');

      await repo.updateShg(created.id, name: created.name, village: 'V', district: 'D', formationDate: null, grade: null);

      final updated = (await repo.fetchAllShgs()).items.firstWhere((s) => s.id == created.id);
      expect(updated.mandal, 'Original Mandal');
      expect(updated.state, 'Original State');
    });
  });
}
