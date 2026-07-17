import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shg_saathi/routes/router.dart';
import 'package:shg_saathi/state/app_state.dart';

/// Regression cover for the router's `errorBuilder` (added alongside a
/// global `ErrorWidget.builder` and `runZonedGuarded` in main.dart) —
/// before this, an unmatched route fell back to GoRouter's plain default
/// error page instead of the app's own friendly "Page not found" screen.
void main() {
  testWidgets('an unmatched route renders the friendly not-found screen, not a crash', (tester) async {
    // Default test surface is too short for the splash page's content
    // (matches the same fix in app_smoke_test.dart) — size like a real phone.
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final appState = AppState();
    await appState.init();
    final router = buildRouter(appState);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.go('/this-route-does-not-exist');
    await tester.pumpAndSettle();

    expect(find.text('Page not found'), findsOneWidget);
    expect(find.text('Go to Home'), findsOneWidget);
  });
}
