import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/auth/login_page.dart';

/// Confirms the language picker (Settings/Language pages, wired in
/// AppState.language -> main.dart's MaterialApp.router `locale`) actually
/// changes displayed text, not just a stored preference — regression cover
/// for the real Flutter l10n wiring added this session. LoginPage is the
/// simplest real page to pump directly (no Provider/AppState dependency).
void main() {
  Future<void> pumpLogin(WidgetTester tester, Locale locale) => tester.pumpWidget(MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LoginPage(),
      ));

  testWidgets('renders English strings for the en locale', (tester) async {
    await pumpLogin(tester, const Locale('en'));
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Send OTP'), findsOneWidget);
  });

  testWidgets('renders Telugu strings for the te locale', (tester) async {
    await pumpLogin(tester, const Locale('te'));
    expect(find.text('తిరిగి స్వాగతం'), findsOneWidget);
    expect(find.text('OTP పంపండి'), findsOneWidget);
  });

  testWidgets('renders Hindi strings for the hi locale', (tester) async {
    await pumpLogin(tester, const Locale('hi'));
    expect(find.text('वापसी पर स्वागत है'), findsOneWidget);
    expect(find.text('OTP भेजें'), findsOneWidget);
  });
}
