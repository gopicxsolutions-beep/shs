import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/models/types.dart';
import 'package:shg_saathi/routes/paths.dart';
import 'package:shg_saathi/routes/router.dart';
import 'package:shg_saathi/state/app_state.dart';

/// Regression cover for the round-66/68-diagnosed, previously-deferred gap:
/// an unauthenticated visit to a deep link (e.g. a bookmarked loan detail
/// page) used to bounce to the splash screen and lose the original
/// destination forever, landing the user on the plain dashboard after they
/// signed in instead of back where they meant to go. The router's
/// `redirect` now captures a genuine `/app/**` target on `AppState` (see
/// `AppState.capturePendingDeepLink`) for `OtpPage` to replay after
/// verification — these tests exercise the router/`AppState` half of that
/// contract directly (demo mode, matching `all_routes_smoke_test.dart`'s
/// harness), since `OtpPage` itself needs a live Supabase session to reach
/// its own OTP-verified branch and has no existing test scaffolding for
/// that.
void main() {
  Future<GoRouter> boot(WidgetTester tester, AppState appState, Map<String, Object> prefs) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues(prefs);
    await appState.init();
    final router = buildRouter(appState);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp.router(
          routerConfig: router,
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
    return router;
  }

  String currentPath(GoRouter router) => router.routerDelegate.currentConfiguration.uri.path;

  testWidgets('an unauthenticated visit to a real /app/** deep link is captured and bounced to splash', (tester) async {
    final appState = AppState();
    final router = await boot(tester, appState, const {});

    router.go(Paths.loanDetail('abc123'));
    await tester.pumpAndSettle();

    expect(currentPath(router), Paths.splash, reason: 'still unauthenticated — must stay confined to the auth flow');
    expect(appState.pendingDeepLink, Paths.loanDetail('abc123'), reason: 'the genuine deep link must be captured for replay after sign-in');
  });

  testWidgets('an unauthenticated visit to an unknown /app-prefixed URL is NOT captured', (tester) async {
    final appState = AppState();
    final router = await boot(tester, appState, const {});

    router.go('/app/this-route-does-not-exist');
    await tester.pumpAndSettle();

    expect(currentPath(router), Paths.splash);
    expect(appState.pendingDeepLink, isNull, reason: 'a malformed/unregistered URL must not be replayed later as if it were a real destination');
  });

  testWidgets('an unauthenticated visit to an auth-flow route (not /app/**) captures nothing', (tester) async {
    final appState = AppState();
    final router = await boot(tester, appState, const {});

    router.go(Paths.login);
    await tester.pumpAndSettle();

    expect(currentPath(router), Paths.login);
    expect(appState.pendingDeepLink, isNull);
  });

  testWidgets('a captured deep link the signed-in user IS allowed to see is reachable once onboarding is complete', (tester) async {
    final appState = AppState();
    final router = await boot(tester, appState, const {});

    router.go(Paths.loanDetail('abc123'));
    await tester.pumpAndSettle();
    final captured = appState.pendingDeepLink;
    expect(captured, isNotNull);

    // Mirrors demo mode's own two-step "sign-in" (session, then profile) —
    // see ProfileSetupPage/RoleSelectPage — landing on a plain member.
    await appState.completeProfileSetup(name: 'Asha', village: 'Anantapur');
    await appState.setRole(Role.member);

    // What OtpPage._submit now does after a successful verification: only
    // replay the captured link once onboarding is fully clear.
    expect(appState.needsRoleSelection, isFalse);
    final target = appState.consumePendingDeepLink();
    expect(target, captured);
    router.go(target!);
    await tester.pumpAndSettle();

    expect(currentPath(router), Paths.loanDetail('abc123'), reason: 'a member is allowed on a loan detail page — the deep link must land there, not on the plain dashboard');
    expect(appState.pendingDeepLink, isNull, reason: 'single-use — must not still be sitting there for a later, unrelated navigation to replay');
  });

  testWidgets('a captured deep link the signed-in user is NOT allowed to see still gets role-restricted away', (tester) async {
    final appState = AppState();
    final router = await boot(tester, appState, const {});

    // Paths.adminUsers ('/app/admin/users') is a genuine registered route,
    // restricted to Role.admin by router.dart's _roleRestrictedPrefixes.
    router.go(Paths.adminUsers);
    await tester.pumpAndSettle();
    final captured = appState.pendingDeepLink;
    expect(captured, Paths.adminUsers);

    await appState.completeProfileSetup(name: 'Asha', village: 'Anantapur');
    await appState.setRole(Role.member);

    final target = appState.consumePendingDeepLink();
    router.go(target!);
    await tester.pumpAndSettle();

    expect(
      currentPath(router),
      Paths.dashboard,
      reason: 'the existing _roleRestrictedPrefixes redirect must still catch a programmatic navigation to a role-restricted target exactly as it does for any other navigation',
    );
  });
}
