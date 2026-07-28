import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/shg/shg_members_page.dart';
import 'package:shg_saathi/state/app_state.dart';

/// Same fix template as `shg_financial_summary_page_test.dart`/
/// `shg_performance_report_page_test.dart` (see docs/SRS.md's §3.16 note):
/// `ShgMembersPage` now takes an optional `shgId`/`shgName` that overrides
/// the viewer's own SHG when provided, without changing the leader/member's
/// original own-SHG behavior when omitted.
void main() {
  testWidgets('an explicit shgId + shgName shows that SHG\'s name in the header and hides the leader-only join-requests button', (tester) async {
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
          home: const ShgMembersPage(shgId: 'g1', shgName: 'Sri Durga Mahila SHG'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Members'), findsOneWidget);
    expect(find.text('Sri Durga Mahila SHG'), findsOneWidget, reason: 'the SHG name must show in the header so staff know whose roster this is');
    expect(find.byTooltip('Join requests'), findsNothing, reason: 'join-request management stays scoped to the leader managing her own SHG, not a staff cross-SHG view');
    expect(tester.takeException(), isNull);
  });

  testWidgets('with no shgId provided, falls back to the viewer\'s own profile and shows no SHG-name subtitle (leader/member original behavior, unaffected)', (tester) async {
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
          home: const ShgMembersPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Members'), findsOneWidget);
    expect(find.text('Sri Durga Mahila SHG'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
