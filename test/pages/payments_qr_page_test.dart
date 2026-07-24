import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shg_saathi/pages/payments/payments_qr_page.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/state/app_state.dart';

/// Regression coverage for the amount field's client-side validation —
/// mirrors `loan_apply_page.dart`/`savings_entry_page.dart`'s own tests for
/// the identical `_maxAmount` sanity-ceiling convention, which this page was
/// previously missing.
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  Widget harness() => ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: const MaterialApp(home: PaymentsQrPage()),
      );

  testWidgets('tapping Pay Now with an empty amount shows a validation error instead of crashing', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pay Now'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Enter a valid amount'), findsOneWidget);
  });

  testWidgets('tapping Pay Now with a zero amount shows a validation error', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.text('Pay Now'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Enter a valid amount'), findsOneWidget);
  });

  testWidgets('an unreasonably large amount is rejected with a sanity-check message', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '5000000');
    await tester.tap(find.text('Pay Now'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Amount seems unusually large — please check and re-enter'), findsOneWidget);
  });
}
