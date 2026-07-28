import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/reports/shg_performance_report_page.dart';
import 'package:shg_saathi/state/app_state.dart';

/// FR-RPT-2 (docs/SRS.md): same fix as `shg_financial_summary_page_test.dart`
/// — `ShgPerformanceReportPage` now takes an optional `shgId`/`shgName` that
/// overrides the viewer's own SHG when provided.
void main() {
  testWidgets('an explicit shgId + shgName renders that SHG\'s performance report and shows its name in the header', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ShgPerformanceReportPage(shgId: 'g1', shgName: 'Sri Durga Mahila SHG'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Performance Report'), findsOneWidget);
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
          home: const ShgPerformanceReportPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Performance Report'), findsOneWidget);
    expect(find.text('Sri Durga Mahila SHG'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
