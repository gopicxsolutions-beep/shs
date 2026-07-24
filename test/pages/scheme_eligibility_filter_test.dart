import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/schemes/scheme_eligibility_page.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/state/app_state.dart';
import 'package:shg_saathi/widgets/app_card.dart';

/// Regression coverage for the eligibility checker page's structured rules
/// engine (see `evaluateSchemeEligibility` in `lib/models/scheme.dart` for
/// the pure-logic unit tests) — this file locks in the widget-level
/// behavior: real per-criterion ✓/✗ reasons render for a scheme that
/// declares structured criteria, and the old free-text keyword-matching
/// heuristic (yes/no toggle switches matched against `eligibility` prose)
/// is gone entirely.
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  Widget harness() => ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: MaterialApp(home: const SchemeEligibilityPage(), localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], supportedLocales: AppLocalizations.supportedLocales, ),
      );

  testWidgets('renders itemized per-criterion checks for a scheme with structured criteria, not a toggle UI', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // DAY-NRLM (lib/data/schemes.dart, sc1) declares requiresShgMembership
    // + minShgAgeMonths: 6. Demo mode's persona is always a fully onboarded
    // member of a long-established SHG (formed 12 Jun 2014), so both
    // criteria are met. Scope the assertion to DAY-NRLM's own card — several
    // mock schemes share the same requiresShgMembership criterion, so the
    // reason text legitimately repeats across cards.
    expect(find.text('DAY-NRLM'), findsOneWidget);
    final dayNrlmCard = find.ancestor(of: find.text('DAY-NRLM'), matching: find.byType(AppCard));
    expect(dayNrlmCard, findsOneWidget);
    expect(find.descendant(of: dayNrlmCard, matching: find.textContaining('SHG membership — you are linked to an SHG')), findsOneWidget);
    expect(find.descendant(of: dayNrlmCard, matching: find.textContaining('requires 6+')), findsOneWidget);

    // The old toggle-switch UI ("BPL / rural household" as a tappable
    // criterion switch) must not still be present.
    expect(find.byType(SwitchListTile), findsNothing);

    // Every scheme should render an Eligible/Not eligible/See full details
    // badge, not a raw match score.
    expect(find.text('Eligible'), findsWidgets);
  });

  testWidgets('a scheme with no structured criteria shows a neutral note instead of a false eligible claim', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    // PMEGP (sc2) has no structured criteria set (see lib/data/schemes.dart)
    // — Stand-Up India (sc4) also has none, so this note legitimately
    // appears more than once.
    expect(find.text('PMEGP'), findsOneWidget);
    expect(find.text('No automatic eligibility criteria set for this scheme — open it to see the full requirements.'), findsWidgets);
  });
}
