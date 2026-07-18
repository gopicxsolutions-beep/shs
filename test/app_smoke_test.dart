import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shg_saathi/main.dart';

/// End-to-end smoke test of the demo-mode boot flow (no Supabase
/// configured, matching how flutter-web-demo runs) — boots the real app
/// widget tree, lands on the splash screen, and follows "Get Started" into
/// the login flow.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('boots to the splash screen and navigates into the login flow', (tester) async {
    // The default 800x600 test surface is too short for the splash page's
    // content and clips "Get Started" out of the hit-testable area — size
    // the surface like a real phone instead.
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ShgSaathiApp());
    await tester.pumpAndSettle();

    expect(find.text('Get Started'), findsOneWidget);
    expect(find.textContaining('Empowering Women'), findsOneWidget);

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
  });
}
