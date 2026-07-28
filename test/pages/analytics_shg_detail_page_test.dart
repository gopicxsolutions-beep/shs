import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/analytics/analytics_shg_detail_page.dart';

/// FR-RPT-2 (docs/SRS.md): `AnalyticsShgDetailPage` (crp/clf/admin's
/// cross-SHG oversight page) previously dead-ended — no link anywhere to
/// this SHG's Financial Summary/Performance Report, the two pages FR-RPT-2
/// actually names, even though both already resolve any explicit shgId via
/// the same `is_staff()` RLS bypass this page's own `fetchShgDetail()` uses.
/// This proves the new "view full report" cards this round added actually
/// render, with the right SHG-specific title/subtitle pair.
void main() {
  Future<void> pumpPage(WidgetTester tester, String shgId) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AnalyticsShgDetailPage(shgId: shgId),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the SHG name and both new report drill-down cards', (tester) async {
    // lib/data/analytics.dart's shgsForMonitoring: g1 = 'Sri Durga Mahila SHG'.
    await pumpPage(tester, 'g1');

    expect(find.text('Sri Durga Mahila SHG'), findsOneWidget);
    expect(find.text('Financial Summary'), findsOneWidget);
    expect(find.text('Savings, loans & attendance at a glance'), findsOneWidget);
    expect(find.text('Performance Report'), findsOneWidget);
    expect(find.text('Attendance trend & loan activity'), findsOneWidget);
    expect(find.text('View Members'), findsOneWidget);
    expect(find.text('Full roster of this SHG'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unknown SHG id shows the not-found state, no report cards', (tester) async {
    await pumpPage(tester, 'does-not-exist');

    expect(find.text('This SHG could not be found'), findsOneWidget);
    expect(find.text('Financial Summary'), findsNothing);
    expect(find.text('Full roster of this SHG'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
