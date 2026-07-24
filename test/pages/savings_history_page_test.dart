import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/models/profile.dart';
import 'package:shg_saathi/models/savings.dart';
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
  Widget harness(AppState appState) => ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(home: const SavingsHistoryPage(), localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], supportedLocales: AppLocalizations.supportedLocales, ),
      );

  testWidgets('SavingsHistoryPage shows the loaded entries, not the loading or empty state', (tester) async {
    await tester.pumpWidget(harness(AppState()));
    await tester.pumpAndSettle();

    // The demo-mode default member ('Lakshmi Devi') owns exactly one mock
    // entry (lib/data/savings.dart's 's1': verified, 500, UPI, Weekly) —
    // asserting its rendered title/amount (rather than just "the empty-state
    // widget type is absent") actually proves the fetched data reached the
    // screen, not merely that some unrelated widget type is missing.
    expect(find.text('No savings history yet'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Weekly savings'), findsOneWidget);
    expect(find.text('₹500'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unrelated AppState change does not remount the async loader (stable GlobalKey, no spurious re-fetch)', (tester) async {
    final appState = AppState();
    await tester.pumpWidget(harness(appState));
    await tester.pumpAndSettle();

    final builderStateBefore = tester.state<AppAsyncBuilderState<List<SavingsEntry>>>(
      find.byType(AppAsyncBuilder<List<SavingsEntry>>),
    );

    // Any AppState change re-runs SavingsHistoryPage.build() via its
    // context.watch<AppState>() call — setPendingShg is a convenient,
    // savings-unrelated way to trigger exactly that. Before the fix, `_key`
    // was a fresh GlobalKey allocated inside build() on every rebuild, so
    // this would force AppAsyncBuilder to unmount and remount: a brand-new
    // State instance, meaning a silent second call to fetchForMember() that
    // discards the already-loaded list and flashes back to the spinner.
    appState.setPendingShg(const ShgSearchResult(id: 's1', name: 'Test SHG', village: 'V', mandal: 'M', district: 'D'));
    await tester.pumpAndSettle();

    final builderStateAfter = tester.state<AppAsyncBuilderState<List<SavingsEntry>>>(
      find.byType(AppAsyncBuilder<List<SavingsEntry>>),
    );
    expect(
      identical(builderStateBefore, builderStateAfter),
      isTrue,
      reason: 'a new AppAsyncBuilder State instance means the GlobalKey was reallocated on rebuild and a spurious remount/re-fetch happened',
    );
    expect(tester.takeException(), isNull);
  });
}
