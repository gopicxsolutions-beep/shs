import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/pages/schemes/scheme_eligibility_page.dart';
import 'package:shg_saathi/services/supabase_service.dart';

/// Regression coverage for the eligibility filter's toggle behavior —
/// previously only confirmed via a now-unavailable live-browser check
/// ("the eligibility filter toggle actually changing results"), documented
/// in an earlier session. This locks that same claim in as an automated
/// test.
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  testWidgets('turning off a matching criterion removes a scheme from the eligible list', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SchemeEligibilityPage()));
    await tester.pumpAndSettle();

    // DAY-NRLM's mock eligibility text includes "BPL / rural household",
    // and every toggle defaults to true, so it should start out eligible.
    expect(find.text('DAY-NRLM'), findsOneWidget);

    await tester.tap(find.text('BPL / rural household'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('DAY-NRLM'), findsNothing, reason: 'DAY-NRLM requires a rural/BPL household, so turning that criterion off should exclude it');
  });
}
