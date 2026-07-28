import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/reports/shg_financial_summary_page.dart';
import 'package:shg_saathi/state/app_state.dart';

/// FR-RPT-2 (docs/SRS.md): `ShgFinancialSummaryPage` used to resolve "which
/// SHG" only from the viewer's own profile — no way for a crp/clf/admin
/// account to see a *different* SHG's summary. Now takes an optional
/// `shgId`/`shgName` (wired from `AnalyticsShgDetailPage`'s new "View
/// Financial Summary" card) that overrides the viewer's own SHG when
/// provided, without changing the leader's original own-SHG behavior when
/// omitted.
void main() {
  testWidgets('an explicit shgId + shgName renders that SHG\'s report and shows its name in the header, no AppState needed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ShgFinancialSummaryPage(shgId: 'g1', shgName: 'Sri Durga Mahila SHG'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Financial Summary'), findsOneWidget);
    expect(find.text('Sri Durga Mahila SHG'), findsOneWidget, reason: 'the SHG name must show in the header so staff know whose report this is');
    expect(tester.takeException(), isNull);
  });

  testWidgets('with no shgId provided, falls back to the viewer\'s own profile shgId and shows no SHG-name subtitle (leader\'s original behavior, unaffected)', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ShgFinancialSummaryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Financial Summary'), findsOneWidget);
    expect(find.text('Sri Durga Mahila SHG'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
