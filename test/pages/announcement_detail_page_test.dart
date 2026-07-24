import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/announcements/announcement_detail_page.dart';
import 'package:shg_saathi/state/app_state.dart';

/// Regression test for the markRead isolation fix: a markRead failure must
/// not surface as an AppAsyncBuilder error page, hiding successfully-loaded
/// announcement content. In demo mode markRead is a no-op, but the fix
/// ensures that even a real markRead exception never propagates to the
/// AppAsyncBuilder error boundary.
void main() {
  Widget harness(String id) => ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: MaterialApp(home: AnnouncementDetailPage(announcementId: id), localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], supportedLocales: AppLocalizations.supportedLocales, ),
      );

  testWidgets('announcement title and body render in demo mode', (tester) async {
    await tester.pumpWidget(harness('an1'));
    await tester.pumpAndSettle();

    expect(find.text('DAY-NRLM interest subvention circular'), findsOneWidget);
    expect(find.text('New interest subvention rates effective from July 2026 for SHGs with A grade.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown announcement id shows empty-state, not an exception', (tester) async {
    await tester.pumpWidget(harness('does-not-exist'));
    await tester.pumpAndSettle();

    expect(find.text('This announcement could not be found'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
