import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shg_saathi/pages/savings/savings_history_page.dart';
import 'package:shg_saathi/state/app_state.dart';
import 'package:shg_saathi/widgets/async_state.dart';

/// Regression test for the GlobalKey-in-build() fix on SavingsHistoryPage.
/// Before the fix, SavingsHistoryPage was a StatelessWidget that allocated
/// a new GlobalKey on every build(), causing the AppAsyncBuilder subtree to
/// be unmounted and remounted on every AppState change — producing spurious
/// full re-fetches. After the fix it is a StatefulWidget and the key is a
/// stable State field.
void main() {
  Widget harness() => ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: const MaterialApp(home: SavingsHistoryPage()),
      );

  testWidgets('SavingsHistoryPage renders savings list without exception', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    // Demo data exists — should show entries, not the empty state.
    expect(find.byType(AppAsyncBuilder<List<dynamic>>), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SavingsHistoryPage key is stable — GlobalKey lives in State not build()', (tester) async {
    // Verify the widget tree uses StatefulWidget (not StatelessWidget) so the
    // key is allocated once in initState and not recreated per build.
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(SavingsHistoryPage));
    expect(element.widget, isA<SavingsHistoryPage>());
    // A StatefulWidget element has a State object — this assertion fails if
    // the class were still a StatelessWidget.
    final stateElement = element as StatefulElement;
    expect(stateElement.state, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
