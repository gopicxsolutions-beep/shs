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
}
