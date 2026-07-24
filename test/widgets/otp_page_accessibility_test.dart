import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/auth/otp_page.dart';

/// The 6 OTP boxes are visually identical single-digit `TextField`s with no
/// label — a sighted user infers "this is the code" from the screen title
/// and left-to-right position. A screen reader has neither cue: without a
/// per-box label it announces 6 indistinguishable "edit box" nodes with no
/// indication they're digits 1-6 of one code. Regression coverage for the
/// `MergeSemantics` + `Semantics(label:)` fix added this session.
void main() {
  testWidgets('each OTP digit box exposes a distinct position label to a screen reader', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: OtpPage(phone: '+91 98765 43210'),
    ));

    for (var i = 1; i <= 6; i++) {
      final label = tester.getSemantics(find.bySemanticsLabel('OTP digit $i of 6'));
      expect(label, isNotNull, reason: 'digit box $i is missing its position label');
    }
  });
}
