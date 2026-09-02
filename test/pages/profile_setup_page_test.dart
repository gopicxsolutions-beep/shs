import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/auth/profile_setup_page.dart';
import 'package:shg_saathi/state/app_state.dart';
import 'package:shg_saathi/widgets/app_button.dart';

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
}
