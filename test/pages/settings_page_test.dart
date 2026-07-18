import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/profile/settings_page.dart';
import 'package:shg_saathi/state/app_state.dart';

/// Regression coverage for SettingsPage's `_loadPrefs()`/`_setPref()` fixes.
/// Before the fix, `_loadPrefs()` had no error handling at all — `_loaded`
/// only ever became true on the success path, so the page would be stuck on
/// its CircularProgressIndicator forever if SharedPreferences ever threw.
/// `_setPref()` was fire-and-forget from a Switch.onChanged with no
/// rollback, so a save failure left the toggle showing a value that was
/// never actually persisted, with zero user feedback.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget harness() => ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: MaterialApp(
          home: const SettingsPage(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );

  testWidgets('settings load past the spinner and toggling a switch persists without exception', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing, reason: '_loadPrefs() must resolve _loaded=true even under error, not hang forever');
    expect(find.byType(Switch), findsWidgets);

    final aSwitch = find.byType(Switch).first;
    final before = tester.widget<Switch>(aSwitch).value;
    await tester.tap(aSwitch);
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(aSwitch).value, !before);
    expect(tester.takeException(), isNull);
  });
}
