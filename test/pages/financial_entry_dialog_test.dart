import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/pages/financial/financial_entry_dialog.dart';
import 'package:shg_saathi/repositories/financial_repository.dart';
import 'package:shg_saathi/services/supabase_service.dart';

/// Regression coverage for a silent-failure fix: tapping "Add" with an
/// invalid amount used to close the dialog with zero feedback (no crash,
/// no error message — the user just saw nothing happen). Validation now
/// runs inside the dialog and shows a real error instead.
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  Future<void> openDialog(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => showFinancialEntryDialog(context, FinancialRepository(), shgId: 'shg1', createdBy: 'member1', entryType: 'cashbook'),
            child: const Text('Open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('tapping Add with an empty description shows an error and keeps the dialog open', (tester) async {
    await openDialog(tester);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Enter a description'), findsOneWidget);
    expect(find.text('Add entry'), findsOneWidget);
  });

  testWidgets('tapping Add with a description but no amount shows an error and keeps the dialog open', (tester) async {
    await openDialog(tester);

    await tester.enterText(find.byType(TextField).first, 'Weekly collection');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Enter a valid amount'), findsOneWidget);
    expect(find.text('Add entry'), findsOneWidget);
  });
}
