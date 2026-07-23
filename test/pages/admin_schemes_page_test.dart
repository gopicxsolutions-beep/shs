import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/models/scheme.dart';
import 'package:shg_saathi/pages/admin/admin_schemes_page.dart';
import 'package:shg_saathi/repositories/scheme_repository.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/state/app_state.dart';

/// Regression coverage for the "Add scheme"/"Edit scheme" dialogs' new
/// structured eligibility-criteria fields (`EligibilityCriteria` in
/// `lib/models/scheme.dart`) — an admin can now actually set these when
/// creating a scheme, not just its free-text name/agency/benefit.
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  Future<void> boot(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(const {
      'shg_session_started': true,
      'shg_authenticated': true,
      'shg_role': 'admin',
    });
    final appState = AppState();
    await appState.init();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          home: const AdminSchemesPage(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Add scheme dialog exposes structured eligibility criteria fields', (tester) async {
    await boot(tester);

    await tester.tap(find.byTooltip('Add scheme'));
    await tester.pumpAndSettle();

    expect(find.text('Requires SHG membership'), findsOneWidget);
    expect(find.text('Minimum SHG age in months (optional)'), findsOneWidget);
    // The grade dropdown's hint is rendered by `InputDecorator`/`DropdownButton`
    // internals rather than a plain `Text` widget find.text can match reliably,
    // so assert on the form field itself instead.
    expect(find.byType(DropdownButtonFormField<String?>), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('creating a scheme with structured criteria actually persists them (demo mode)', (tester) async {
    await boot(tester);

    await tester.tap(find.byTooltip('Add scheme'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Scheme name'), '__TEST__ Widget Scheme');
    await tester.tap(find.text('Requires SHG membership'));
    await tester.enterText(find.widgetWithText(TextField, 'Minimum SHG age in months (optional)'), '9');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Demo mode — scheme not saved (connect Supabase to persist)'), findsOneWidget);

    final schemes = await SchemeRepository().fetchSchemes();
    final created = schemes.firstWhere((s) => s.name == '__TEST__ Widget Scheme');
    expect(created.criteria.requiresShgMembership, isTrue);
    expect(created.criteria.minShgAgeMonths, 9);
  });

  testWidgets('a non-numeric minimum SHG age shows a validation message instead of silently saving', (tester) async {
    await boot(tester);

    await tester.tap(find.byTooltip('Add scheme'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Scheme name'), '__TEST__ Invalid Age Scheme');
    await tester.enterText(find.widgetWithText(TextField, 'Minimum SHG age in months (optional)'), 'abc');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Minimum SHG age must be a whole number of months.'), findsOneWidget);

    final schemes = await SchemeRepository().fetchSchemes();
    expect(schemes.any((s) => s.name == '__TEST__ Invalid Age Scheme'), isFalse);
  });

  // Regression coverage for the dropdown-crash-risk bug: the Edit-scheme
  // dialog's grade DropdownButtonFormField used to set `initialValue`
  // straight from the stored `min_shg_grade` with no validation. If that
  // value were ever outside the exact 5-item vocabulary (e.g. written
  // directly via SQL, bypassing this form — there's no DB CHECK constraint),
  // opening Edit tripped a Flutter value-matching assertion/crash instead of
  // falling back gracefully.
  testWidgets('editing a scheme with an out-of-vocabulary stored min_shg_grade does not crash and falls back to no minimum', (tester) async {
    await SchemeRepository().createScheme(
      name: '__TEST__ Bad Grade Scheme',
      // Simulates a scheme whose min_shg_grade was written outside this
      // form (e.g. direct SQL) — 'Z' is not one of the 5 recognized
      // A+/A/B+/B/C grades.
      criteria: const EligibilityCriteria(minShgGrade: 'Z'),
    );

    await boot(tester);

    // The newly-added scheme may be scrolled out of the ListView's initial
    // viewport (there are several mock schemes plus earlier tests' __TEST__
    // ones ahead of it) — scroll it into view before tapping.
    await tester.scrollUntilVisible(find.byTooltip('Edit __TEST__ Bad Grade Scheme'), 200);
    await tester.pumpAndSettle();

    // Before the fix, this set the grade dropdown's initialValue to 'Z',
    // matching none of its DropdownMenuItems — a crash, not a graceful
    // fallback.
    await tester.tap(find.byTooltip('Edit __TEST__ Bad Grade Scheme'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(DropdownButtonFormField<String?>), findsOneWidget);

    // Saving without touching the grade field must persist the fallback
    // (no minimum), not the invalid stored value.
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final schemes = await SchemeRepository().fetchSchemes();
    final updated = schemes.firstWhere((s) => s.name == '__TEST__ Bad Grade Scheme');
    expect(updated.criteria.minShgGrade, isNull);
  });
}
