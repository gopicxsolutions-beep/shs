import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/meetings/meeting_schedule_page.dart';
import 'package:shg_saathi/state/app_state.dart';

/// Regression coverage for a maxLength gap this session's earlier sweep
/// missed (that pass grepped a hardcoded list of controller variable
/// names that didn't include this page's `_venue`/`_agenda`) — both fields
/// had no character limit at all until now.
void main() {
  Widget harness() => ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: MaterialApp(home: const MeetingSchedulePage(), localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], supportedLocales: AppLocalizations.supportedLocales, ),
      );

  testWidgets('Venue and Agenda fields enforce their maxLength', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    final venueField = tester.widget<TextField>(find.widgetWithText(TextField, 'e.g. Anganwadi Centre, Kondapur', skipOffstage: false));
    expect(venueField.maxLength, 150);

    final agendaField = tester.widget<TextField>(find.widgetWithText(TextField, 'e.g. Monthly savings review & loan applications', skipOffstage: false));
    expect(agendaField.maxLength, 300);

    expect(tester.takeException(), isNull);
  });
}
