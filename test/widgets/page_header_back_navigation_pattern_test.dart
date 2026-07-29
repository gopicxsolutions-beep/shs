import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shg_saathi/layout/page_header.dart';
import 'package:shg_saathi/routes/navigation_history.dart';
import 'package:shg_saathi/routes/paths.dart';
import 'package:shg_saathi/state/unsaved_changes.dart';

/// Regression coverage for `PageHeader._goBack` (round 16) and the
/// `UnsavedChanges` discard-confirmation flow it now checks first (round 18).
///
/// Every route in this app is a flat `ShellRoute` sibling reached via
/// `context.go()`, so there's normally nothing in the `Navigator` stack for
/// `Navigator.maybePop()` to act on — before round 16's fix, tapping
/// `PageHeader`'s Back arrow on nearly every sub-page was a silent no-op.
/// Round 18 then layered an unsaved-input guard onto that same Back button
/// (and the bottom nav's tap handler in `app_shell.dart`, which shares the
/// identical check/dialog/clear-flag shape) since a `context.go()` full-page-
/// stack replace also bypasses `PopScope`. Both fixes live entirely inside
/// `PageHeader._goBack`, so a minimal two-route `GoRouter` — one page showing
/// `PageHeader` with nothing to pop, one standing in for the dashboard — is
/// enough to exercise the real mechanism without a full app/Supabase setup.
GoRouter _buildTestRouter() {
  return GoRouter(
    initialLocation: '/test-page',
    routes: [
      GoRoute(path: Paths.dashboard, builder: (context, state) => const Scaffold(body: Text('Dashboard Home'))),
      GoRoute(
        path: '/test-page',
        builder: (context, state) => Scaffold(appBar: PageHeader(title: 'Test Page'), body: const SizedBox()),
      ),
    ],
  );
}

void main() {
  setUp(() {
    UnsavedChanges.dirty = false;
    // NavigationHistory is process-wide static state (router.dart's
    // `redirect` populates it in the real app); reset it so one test's
    // recorded visits can't leak into the next.
    NavigationHistory.resetForTest();
  });
  tearDown(() {
    UnsavedChanges.dirty = false;
    NavigationHistory.resetForTest();
  });

  testWidgets('with a recorded previous page, tapping PageHeader Back returns there instead of the dashboard', (tester) async {
    // Simulates what router.dart's `redirect` callback does on every real
    // navigation: record the settled location each time. Visiting the
    // dashboard, then another page, then landing on /test-page mirrors a
    // genuine Dashboard -> Other Page -> Test Page journey.
    NavigationHistory.recordVisit(Paths.dashboard);
    NavigationHistory.recordVisit('/other-page');
    NavigationHistory.recordVisit('/test-page');

    await tester.pumpWidget(MaterialApp.router(routerConfig: _buildTestRouter()));
    await tester.pumpAndSettle();

    expect(find.text('Test Page'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(
      find.text('Dashboard Home'),
      findsNothing,
      reason: 'Back must return to the actual previous page (/other-page), not fall through to the dashboard',
    );
  });

  testWidgets('with nothing to pop, tapping PageHeader Back falls back to the dashboard instead of doing nothing', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _buildTestRouter()));
    await tester.pumpAndSettle();

    expect(find.text('Test Page'), findsOneWidget);
    expect(find.text('Dashboard Home'), findsNothing);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(
      find.text('Dashboard Home'),
      findsOneWidget,
      reason: 'Back must fall back to the dashboard when there is nothing to pop (round 16 fix), not silently no-op',
    );
  });

  testWidgets('a dirty form warns before Back discards it: Keep Editing cancels, Discard proceeds and clears the flag', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _buildTestRouter()));
    await tester.pumpAndSettle();

    UnsavedChanges.dirty = true;

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.text('Test Page'), findsOneWidget, reason: 'navigation must not have happened yet while the dialog is up');

    // "Keep Editing" must cancel the navigation and leave the flag set.
    await tester.tap(find.text('Keep Editing'));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Test Page'), findsOneWidget, reason: 'Keep Editing must not navigate away');
    expect(UnsavedChanges.dirty, isTrue, reason: 'Keep Editing must not clear the dirty flag');

    // Tapping Back again and choosing "Discard" must proceed and clear the flag.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard Home'), findsOneWidget, reason: 'Discard must proceed with the navigation');
    expect(UnsavedChanges.dirty, isFalse, reason: 'Discard must clear the flag so it does not leak onto the next page');
  });
}
