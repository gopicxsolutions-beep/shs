import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/layout/app_shell.dart';
import 'package:shg_saathi/models/types.dart';
import 'package:shg_saathi/routes/paths.dart';
import 'package:shg_saathi/state/app_state.dart';

/// Regression coverage for the bottom-nav overflow fix: the raised center
/// "Services" nav item's 52px icon circle + label summed to slightly more
/// than the fixed 64px nav bar height (Transform.translate repositions
/// content visually but doesn't shrink its measured layout size), firing a
/// RenderFlex overflow on every single page in the app. Fixed by wrapping
/// the item's Column in OverflowBox to relax the height constraint.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('the bottom nav renders with zero exceptions for every role', (tester) async {
    for (final role in Role.values) {
      final appState = AppState();
      await appState.setRole(role);
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: AppShell(location: Paths.dashboard, child: const SizedBox()),
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

      expect(tester.takeException(), isNull, reason: 'Bottom nav overflowed for role $role');
    }
  });
}
