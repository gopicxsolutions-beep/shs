import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/savings/savings_entry_page.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/state/app_state.dart';

/// Regression coverage for a real crash found and fixed this session:
/// `_formKey` (a `GlobalKey<FormState>`) was referenced by validate() but
/// never attached to an actual `Form`, so `_formKey.currentState` was
/// always null and tapping Submit with an empty/invalid amount threw a
/// null-check error instead of showing a validation message.
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  Widget harness() => ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: MaterialApp(home: const SavingsEntryPage(), localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], supportedLocales: AppLocalizations.supportedLocales, ),
      );

  testWidgets('tapping Submit with an empty amount shows a validation error instead of crashing', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Submit Entry'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Enter an amount'), findsOneWidget);
  });

  testWidgets('tapping Submit with a zero amount shows a validation error instead of crashing', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '0');
    await tester.tap(find.text('Submit Entry'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Amount must be greater than zero'), findsOneWidget);
  });

  testWidgets('an unreasonably large amount is rejected with a sanity-check message', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '5000000');
    await tester.tap(find.text('Submit Entry'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Amount seems unusually large — please check and re-enter'), findsOneWidget);
  });
}
