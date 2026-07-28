import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/auth/otp_page.dart';
import 'package:shg_saathi/routes/paths.dart';
import 'package:shg_saathi/services/supabase_service.dart';

/// Regression coverage for the gap-hunt round-184 fix: `OtpPage._phone` used
/// to silently fall back to a hardcoded `'+91 98765 43210'` whenever
/// `widget.phone` (sourced from the router's `state.extra`, which only
/// survives in-memory navigation) was null — a Flutter-web page refresh, a
/// reopened `/otp` tab, or a restored browser tab all reload this route with
/// no `extra`, and the placeholder then fed straight into the REAL
/// `verifyOtp`/`sendOtp` calls with no visible indication anything was
/// wrong. `OtpPage` now redirects back to Login instead in live mode.
void main() {
  setUp(() => SupabaseService.isConfigured = false);
  tearDown(() => SupabaseService.isConfigured = false);

  Future<GoRouter> boot(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: Paths.otp,
      routes: [
        GoRoute(path: Paths.otp, builder: (context, state) => OtpPage(phone: state.extra as String?)),
        GoRoute(path: Paths.login, builder: (context, state) => const Scaffold(body: Text('Login Page'))),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    ));
    await tester.pumpAndSettle();
    return router;
  }

  String currentPath(GoRouter router) => router.routerDelegate.currentConfiguration.uri.path;

  testWidgets('live mode with no phone extra redirects to Login with an explanatory message instead of using a fake number', (tester) async {
    SupabaseService.isConfigured = true;
    final router = await boot(tester);

    expect(currentPath(router), Paths.login);
    expect(find.text('Login Page'), findsOneWidget);
    expect(find.text("Your phone number wasn't found. Please sign in again."), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('demo mode with no phone extra stays on the OTP page (no live verification ever happens)', (tester) async {
    SupabaseService.isConfigured = false;
    final router = await boot(tester);

    expect(currentPath(router), Paths.otp);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a real phone extra is used as-is and never redirects', (tester) async {
    SupabaseService.isConfigured = true;
    final router = GoRouter(
      initialLocation: Paths.otp,
      routes: [
        GoRoute(path: Paths.otp, builder: (context, state) => OtpPage(phone: state.extra as String?)),
        GoRoute(path: Paths.login, builder: (context, state) => const Scaffold(body: Text('Login Page'))),
      ],
    );
    router.go(Paths.otp, extra: '+91 91234 56789');
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    ));
    await tester.pumpAndSettle();

    expect(currentPath(router), Paths.otp);
    // The phone is rendered as a nested TextSpan inside a raw RichText (not
    // a Text/Text.rich, which find.text matches) — and every plain Text
    // widget also lowers to its own RichText internally, so byType(RichText)
    // alone would be ambiguous. Match on the plain-text content instead.
    expect(
      find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('+91 91234 56789')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
