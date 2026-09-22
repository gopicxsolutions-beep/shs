import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/models/profile.dart';
import 'package:shg_saathi/pages/auth/profile_setup_page.dart';
import 'package:shg_saathi/repositories/shg_join_request_repository.dart';
import 'package:shg_saathi/services/auth_service.dart';
import 'package:shg_saathi/services/profile_repository.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/state/app_state.dart';
import 'package:shg_saathi/widgets/app_button.dart';

class _FixedProfileRepository extends ProfileRepository {
  _FixedProfileRepository(this._profile);
  final Profile? _profile;
  @override
  Future<Profile?> fetchMyProfile(String? uid) async => _profile;
}

class _FakeAuthServiceWithSession extends AuthService {
  @override
  Session? get currentSession => Session(
        accessToken: 'token',
        tokenType: 'bearer',
        refreshToken: 'refresh',
        user: User(id: 'p1', appMetadata: const {}, userMetadata: const {}, aud: 'authenticated', createdAt: DateTime(2026).toIso8601String()),
      );

  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();
}

/// Regression coverage for the mandatory-SHG-selection redesign: an SHG pick
/// is now required before Continue enables (previously optional), so that a
/// self-registered Leader always ends up with a real pending join request —
/// closing the gap where she could complete onboarding with no way to ever
/// get linked to an SHG. See app_state.dart's completeProfileSetup and
/// shg_join_requests_page.dart's approve-as-leader option for the rest of
/// this fix.
void main() {
  Future<void> boot(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: MaterialApp(
          home: const ProfileSetupPage(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  AppButton continueButton(WidgetTester tester) => tester.widget<AppButton>(find.byType(AppButton));

  testWidgets('Continue stays disabled with only a name — an SHG pick is required too', (tester) async {
    await boot(tester);

    expect(continueButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, 'Lakshmi Devi');
    await tester.pumpAndSettle();

    expect(continueButton(tester).onPressed, isNull, reason: 'a name alone must not be enough — this is the bug that let a Leader onboard with no SHG at all');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Continue enables once both a name and an SHG are picked', (tester) async {
    await boot(tester);

    await tester.enterText(find.byType(TextField).first, 'Lakshmi Devi');
    await tester.pumpAndSettle();
    // Demo mode's SHG picker card auto-selects a fixed demo SHG synchronously
    // on tap (no real search sheet involved) — see _pickShg's demo branch.
    await tester.tap(find.text('Search & select your SHG'));
    await tester.pumpAndSettle();

    expect(continueButton(tester).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  /// Regression coverage for the "fill every field, not just consent"
  /// requirement: Next must stay disabled on a baseline-survey section
  /// until every field on it is filled/selected — including a
  /// conditionally-revealed "specify" field for an "other(s)" choice, which
  /// is just as required as everything else on that section.
  testWidgets('Section A (baseline survey): Next requires every field, including the conditional "Other" location field', (tester) async {
    // The wizard's per-section content is taller than a default 800x600 test
    // surface, and unlike a real tap gesture, invoking `onPressed` directly
    // (below) never needs the button on-screen — but `tester.tap` on a
    // chip still does, so give the surface enough height that nothing on
    // Section A needs scrolling into view first.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await boot(tester);
    await tester.enterText(find.byType(TextField).first, 'Lakshmi Devi');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search & select your SHG'));
    await tester.pumpAndSettle();

    // A real `tester.tap` needs its target on-screen; `_advance`/`_submit`
    // are plain callbacks, so invoking `onPressed` directly sidesteps that
    // without changing what's actually being exercised (the same callback
    // a real tap would have invoked).
    continueButton(tester).onPressed!();
    await tester.pumpAndSettle();

    AppButton nextButton() => tester.widgetList<AppButton>(find.byType(AppButton)).firstWhere((b) => b.label == 'Next');

    expect(nextButton().onPressed, isNull, reason: 'nothing on Section A is filled yet');

    await tester.enterText(find.byType(TextField).at(0), '32'); // Age
    await tester.tap(find.text('Secondary')); // Education Level
    await tester.enterText(find.byType(TextField).at(1), 'OBC'); // Caste/Community
    await tester.tap(find.text('Married')); // Marital Status
    await tester.enterText(find.byType(TextField).at(2), '4'); // Household Size
    await tester.pumpAndSettle();

    expect(nextButton().onPressed, isNull, reason: 'location and income fields are still empty');

    await tester.tap(find.text('Other')); // Location
    await tester.pumpAndSettle();

    expect(nextButton().onPressed, isNull, reason: "the conditional Specify field revealed by Other is itself required, and income fields are still empty");

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(3), 'Some village'); // Specify (conditional)
    await tester.enterText(fields.at(4), '150000'); // Annual Household Income
    await tester.enterText(fields.at(5), 'Farming'); // Primary Source of Income
    await tester.pumpAndSettle();

    expect(nextButton().onPressed, isNotNull, reason: 'every Section A field, including the conditional one, is now filled');
    expect(tester.takeException(), isNull);
  });

  /// Regression coverage: a live submission was found with `age: 15` — every
  /// Section A field was "filled" (so the check above alone wouldn't have
  /// caught it), but SHG membership requires an adult respondent and
  /// nothing enforced that. Next must stay disabled for a below-minimum age
  /// with a visible reason, not just silently refuse to advance.
  testWidgets('Section A: an under-18 age keeps Next disabled and shows why, a corrected age clears it', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await boot(tester);
    await tester.enterText(find.byType(TextField).first, 'Lakshmi Devi');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search & select your SHG'));
    await tester.pumpAndSettle();
    continueButton(tester).onPressed!();
    await tester.pumpAndSettle();

    AppButton nextButton() => tester.widgetList<AppButton>(find.byType(AppButton)).firstWhere((b) => b.label == 'Next');

    await tester.enterText(find.byType(TextField).at(0), '15'); // Age
    await tester.tap(find.text('Secondary')); // Education Level
    await tester.enterText(find.byType(TextField).at(1), 'OBC'); // Caste/Community
    await tester.tap(find.text('Married')); // Marital Status
    await tester.enterText(find.byType(TextField).at(2), '4'); // Household Size
    await tester.tap(find.text('East Godavari')); // Location
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(3), '150000'); // Annual Household Income
    await tester.enterText(fields.at(4), 'Farming'); // Primary Source of Income
    await tester.pumpAndSettle();

    expect(nextButton().onPressed, isNull, reason: 'every field is filled but the age is below the minimum');
    expect(find.text('Must be at least 18 years old'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(fields.at(0), '32');
    await tester.pumpAndSettle();

    expect(find.text('Must be at least 18 years old'), findsNothing);
    expect(nextButton().onPressed, isNotNull, reason: 'a corrected, valid age clears the error and enables Next');
  });

  /// Regression coverage for the reported "Could not submit the survey": the
  /// table's CHECKs/precision (household_size 1-50, non-negative money,
  /// numeric(12,2), age <= 120, numeric(5,1) years) rejected values the
  /// wizard used to accept as long as the field was merely non-empty, so the
  /// user only found out at the final Submit, with no hint which answer was
  /// wrong. Verified against the live table in the same round.
  group('numeric answers are range-checked before the wizard advances', () {
    Future<void> toSectionA(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await boot(tester);
      await tester.enterText(find.byType(TextField).first, 'Lakshmi Devi');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Search & select your SHG'));
      await tester.pumpAndSettle();
      continueButton(tester).onPressed!();
      await tester.pumpAndSettle();
    }

    AppButton nextButton(WidgetTester tester) => tester.widgetList<AppButton>(find.byType(AppButton)).firstWhere((b) => b.label == 'Next');

    Future<void> fillSectionA(WidgetTester tester, {String age = '32', String household = '4', String income = '150000'}) async {
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), age);
      await tester.tap(find.text('Secondary'));
      await tester.enterText(fields.at(1), 'OBC');
      await tester.tap(find.text('Married'));
      await tester.enterText(fields.at(2), household);
      await tester.tap(find.text('East Godavari'));
      await tester.enterText(fields.at(3), income);
      await tester.enterText(fields.at(4), 'Farming');
      await tester.pumpAndSettle();
    }

    testWidgets('Section A: household size, age ceiling and income are checked, each with a visible reason', (tester) async {
      await toSectionA(tester);
      await fillSectionA(tester);
      expect(nextButton(tester).onPressed, isNotNull, reason: 'baseline: every answer valid');

      final fields = find.byType(TextField);
      for (final bad in ['0', '51', '100', 'abc', '2.5']) {
        await tester.enterText(fields.at(2), bad);
        await tester.pumpAndSettle();
        expect(nextButton(tester).onPressed, isNull, reason: 'household size "$bad" is outside 1-50 / not a whole number');
        expect(find.text('Enter a number between 1 and 50'), findsOneWidget, reason: 'household size "$bad" needs a visible reason');
      }
      await tester.enterText(fields.at(2), '50');
      await tester.pumpAndSettle();
      expect(nextButton(tester).onPressed, isNotNull, reason: 'the boundary value 50 is valid');

      await tester.enterText(fields.at(0), '121');
      await tester.pumpAndSettle();
      expect(nextButton(tester).onPressed, isNull);
      expect(find.text('Enter a number between 18 and 120'), findsOneWidget);
      await tester.enterText(fields.at(0), '120');
      await tester.pumpAndSettle();
      expect(nextButton(tester).onPressed, isNotNull, reason: 'the boundary value 120 is valid');

      for (final bad in ['-1', 'NaN', 'Infinity', '10000000000', 'lots']) {
        await tester.enterText(fields.at(3), bad);
        await tester.pumpAndSettle();
        expect(nextButton(tester).onPressed, isNull, reason: 'income "$bad" is negative / non-finite / overflows numeric(12,2) / not a number');
        expect(find.text('Enter a number between 0 and 9999999999'), findsOneWidget, reason: 'income "$bad" needs a visible reason');
      }
      await tester.enterText(fields.at(3), '0');
      await tester.pumpAndSettle();
      expect(nextButton(tester).onPressed, isNotNull, reason: 'zero income is a legitimate answer');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Section B: years in operation, revenue and employee count are range-checked', (tester) async {
      await toSectionA(tester);
      await fillSectionA(tester);
      nextButton(tester).onPressed!();
      await tester.pumpAndSettle();

      // Section B's only free-text fields (no "Others" sector picked): years,
      // monthly revenue, employees, in that order.
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '2005'); // a calendar year typed instead of a duration
      await tester.enterText(fields.at(1), '10000000000');
      await tester.enterText(fields.at(2), '3000000000');
      await tester.pumpAndSettle();
      expect(find.text('Enter a number between 0 and 100'), findsOneWidget);
      expect(find.text('Enter a number between 0 and 9999999999'), findsOneWidget);
      expect(find.text('Enter a number between 0 and 10000'), findsOneWidget);

      await tester.enterText(fields.at(0), '5.5');
      await tester.enterText(fields.at(1), '25400');
      await tester.enterText(fields.at(2), '5');
      await tester.pumpAndSettle();
      expect(find.textContaining('Enter a number between'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  // Live-audited (2026-09-22) real bug, found via a real account (a
  // `profiles` row exists — name/village were saved once — but no SHG and no
  // `shg_join_requests` row was ever filed, reachable via ShgApprovalPending
  // Page's "Choose an SHG" button): `_surveyOnly` used to be true for ANY
  // existing profile, which skipped step 0 (the SHG picker) straight to the
  // survey. Since `completeProfileSetup` — the only thing that submits a
  // join request — only ever runs when `!_surveyOnly`, submitting the
  // survey left her exactly as unlinked as before, `needsShgApproval` never
  // cleared, and every relogin re-showed the same blank 9-section survey
  // with no way out: from her side, "already registered, asked for the same
  // details all over again," forever.
  group('an existing profile that still needs an SHG is not dropped straight into the survey', () {
    setUp(() {
      SupabaseService.isConfigured = true;
      SharedPreferences.setMockInitialValues({});
    });
    tearDown(() {
      SupabaseService.isConfigured = false;
    });

    Future<AppState> loadedProfile(Profile profile) async {
      final appState = AppState(profileRepository: _FixedProfileRepository(profile), authService: _FakeAuthServiceWithSession(), joinRequestRepository: ShgJoinRequestRepository());
      await appState.refreshProfile();
      return appState;
    }

    testWidgets('shows step 0 (name + SHG picker), not the survey, and pre-fills her existing name/village', (tester) async {
      const profile = Profile(id: 'p1', name: 'Uma', role: 'member', shgId: null, village: 'Rangampeta');
      final appState = await loadedProfile(profile);
      expect(appState.needsShgApproval, isTrue, reason: 'precondition: an existing profile with no SHG and no request at all');

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(home: const ProfileSetupPage(), localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], supportedLocales: AppLocalizations.supportedLocales),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Search & select your SHG'), findsOneWidget, reason: 'this was the bug: she was dropped straight into the survey with no way to ever pick an SHG');
      expect(find.textContaining('Section'), findsNothing, reason: 'no survey-section heading should be showing yet — this is step 0');
      final nameField = tester.widget<TextField>(find.byType(TextField).first);
      expect(nameField.controller?.text, 'Uma', reason: 'already-known info must not be asked for again from a blank field');
      expect(tester.takeException(), isNull);
    });

    testWidgets('an account that only needs the survey (already has an SHG) still skips straight to it, unaffected', (tester) async {
      const profile = Profile(id: 'p1', name: 'Asha', role: 'member', shgId: 'shg-1');
      final appState = await loadedProfile(profile);
      expect(appState.needsShgApproval, isFalse);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(home: const ProfileSetupPage(), localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], supportedLocales: AppLocalizations.supportedLocales),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Search & select your SHG'), findsNothing, reason: 'her SHG is already settled — step 0 must not reappear');
      expect(tester.takeException(), isNull);
    });
  });
}
