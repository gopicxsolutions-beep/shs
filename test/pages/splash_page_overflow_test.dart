import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/auth/splash_page.dart';

/// Regression coverage for the most severe bug found this session: the
/// splash Column relied on a Spacer() to push "Get Started" to the bottom,
/// but Spacer collapses to zero rather than going negative — on short
/// viewports the fixed content (headline + subtitle + feature grid) alone
/// exceeded the available height, and Column clips overflow from whichever
/// children come last, so the button could be pushed off-screen and become
/// completely unreachable. Fixed by making the top content scroll
/// independently while the button/footer stay pinned and always visible.
///
/// This viewport size (732x622) is the Browser pane's actual default that
/// reproduced the bug on every single boot before the fix — deliberately
/// not the tall 400x900 surface app_smoke_test.dart uses.
void main() {
  testWidgets('renders without overflow and keeps Get Started reachable at a short viewport', (tester) async {
    tester.view.physicalSize = const Size(732, 622);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: const SplashPage(), localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], supportedLocales: AppLocalizations.supportedLocales, ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Get Started'), findsOneWidget);

    // The button must actually be within the visible/hit-testable area, not
    // just present in the tree — confirms it wasn't pushed off-screen.
    final buttonRect = tester.getRect(find.widgetWithText(ElevatedButton, 'Get Started'));
    expect(buttonRect.bottom, lessThanOrEqualTo(622), reason: 'Get Started must be within the 622px-tall viewport, not clipped below it');
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('renders without overflow at an even shorter viewport (568px)', (tester) async {
    tester.view.physicalSize = const Size(400, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: const SplashPage(), localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], supportedLocales: AppLocalizations.supportedLocales, ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final buttonRect = tester.getRect(find.widgetWithText(ElevatedButton, 'Get Started'));
    expect(buttonRect.bottom, lessThanOrEqualTo(568));
  });
}
