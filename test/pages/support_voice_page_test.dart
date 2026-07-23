import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/support/support_voice_page.dart';
import 'package:shg_saathi/services/voice_support_service.dart';

class _ThrowingVoiceService implements VoiceSupportService {
  @override
  Future<String> transcribe() async => throw Exception('mic unavailable');

  @override
  Future<String> answer(String question) async => throw Exception('unreachable');
}

/// Regression test for the fire-and-forget `_ask()` fix on SupportVoicePage.
/// Before the fix, `_ask()` had no try/catch — a `transcribe()`/`answer()`
/// failure left `_state` stuck at `listening`/`thinking` forever, and since
/// the mic control is disabled while in those states, the page became
/// permanently unusable for the rest of its lifetime. After the fix, a
/// failure resets `_state` to `answered` (mic tappable again) and shows a
/// friendly error message instead of hanging.
void main() {
  testWidgets('a transcription failure resets the mic control instead of leaving it stuck', (tester) async {
    await tester.pumpWidget(MaterialApp(home: SupportVoicePage(service: _ThrowingVoiceService()), localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], supportedLocales: AppLocalizations.supportedLocales, ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Sorry, something went wrong. Please try again.'), findsOneWidget);
    expect(find.text('Tap to ask again'), findsOneWidget, reason: 'mic control must become tappable again, not stay stuck on Listening…/Finding an answer…');

    // Confirm the mic InkWell's onTap is non-null (control genuinely
    // re-enabled), not disabled the way it is during Listening…/Finding an
    // answer….
    final micInkWell = tester.widget<InkWell>(
      find.ancestor(of: find.byIcon(Icons.mic_rounded), matching: find.byType(InkWell)),
    );
    expect(micInkWell.onTap, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
