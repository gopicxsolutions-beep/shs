import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/admin/admin_shgs_page.dart';
import 'package:shg_saathi/repositories/shg_repository.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/state/app_state.dart';

/// Regression coverage for the "Load more" keyset-pagination fix on
/// `ShgRepository.fetchAllShgs` — mirrors admin_users_page_test.dart's
/// coverage of the equivalent fix on `AdminRepository.fetchAllUsers`. See
/// that file's doc comment for why only the demo-mode path is exercised
/// here (no live Supabase project in this environment).
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
    ShgRepository.debugShgNameOverride = null;
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
          home: const AdminShgsPage(),
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

  testWidgets('renders the demo-mode SHG catalog without crashing', (tester) async {
    await boot(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Sri Durga Mahila SHG'), findsOneWidget);
  });

  testWidgets('does not show a "Load more" button when the page has no more rows (demo mode)', (tester) async {
    await boot(tester);
    // Demo mode's fetchAllShgs() always returns PagedResult(hasMore: false).
    expect(find.text('Load more'), findsNothing);
  });

  test('ShgRepository.fetchAllShgs demo mode returns a single page with hasMore false', () async {
    final page = await ShgRepository().fetchAllShgs();
    expect(page.hasMore, isFalse);
    expect(page.items, isNotEmpty);
  });

  test('ShgRepository.fetchAllShgs demo mode tolerates a non-null afterName cursor without crashing', () async {
    final page = await ShgRepository().fetchAllShgs(afterName: 'Zzz');
    expect(page.hasMore, isFalse);
    expect(page.items, isNotEmpty);
  });

  // Regression coverage for the "no live write path for formation_date/grade"
  // bug — until this fix, the Add SHG dialog exposed only Name/Village/
  // District, there was no Edit-SHG UI at all, and ShgRepository.createShg()
  // had no parameters for either field.
  group('formation date / grade write path', () {
    testWidgets('Add SHG dialog exposes formation date and grade fields', (tester) async {
      await boot(tester);

      await tester.tap(find.byTooltip('Add SHG'));
      await tester.pumpAndSettle();

      expect(find.text('Formation date (optional)'), findsOneWidget);
      expect(find.text('Pick date'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String?>), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('creating an SHG with a grade actually persists it (demo mode)', (tester) async {
      await boot(tester);

      await tester.tap(find.byTooltip('Add SHG'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'SHG name'), '__TEST__ Widget SHG');
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('B+').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Demo mode — SHG not saved (connect Supabase to persist)'), findsOneWidget);

      final shgs = await ShgRepository().fetchAllShgs();
      final created = shgs.items.firstWhere((s) => s.name == '__TEST__ Widget SHG');
      expect(created.grade, 'B+');
    });

    testWidgets('an Edit-SHG dialog exists and setting a missing grade on an existing SHG actually persists it (demo mode)', (tester) async {
      await boot(tester);

      // The fixed demo SHG renders with an Edit button now that this fix
      // adds an Edit-SHG UI — before this fix there was no way to reach an
      // edit dialog for any SHG, existing or newly created.
      expect(find.byTooltip('Edit Sri Durga Mahila SHG'), findsOneWidget);

      await tester.tap(find.byTooltip('Edit Sri Durga Mahila SHG'));
      await tester.pumpAndSettle();

      expect(find.text('Edit SHG'), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('C').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Demo mode — SHG not saved (connect Supabase to persist)'), findsOneWidget);

      final shgs = await ShgRepository().fetchAllShgs();
      final updated = shgs.items.firstWhere((s) => s.id == 'demo-shg');
      expect(updated.grade, 'C');
    });
  });
}
