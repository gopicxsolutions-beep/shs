import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/admin/admin_users_page.dart';
import 'package:shg_saathi/repositories/admin_repository.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/state/app_state.dart';
import 'package:shg_saathi/widgets/app_card.dart';

/// Regression coverage for the "Load more" keyset-pagination fix on
/// `AdminRepository.fetchAllUsers` — see that method's doc comment for the
/// bug it replaces (a flat `.limit(500)` that silently hid anything past
/// the 500th user alphabetically, with no UI signal at all).
///
/// This only exercises the demo-mode path (no live Supabase project in this
/// environment) — demo mode's mock roster is small and always returns
/// `hasMore: false` in one page, so these confirm the page's pagination UI
/// stays correctly hidden in that case rather than always rendering a dead
/// "Load more" button. The live-mode keyset query itself (`.gt('name',
/// afterName)`, the page-boundary "Load more" tap flow against a real
/// >100-row `profiles` table) needs manual verification against a live
/// Supabase project, which this environment does not have.
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
    AdminRepository.debugMembersOverride = null;
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
          home: const AdminUsersPage(),
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

  testWidgets('renders the demo-mode user roster without crashing', (tester) async {
    await boot(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Lakshmi Devi'), findsOneWidget);
  });

  testWidgets('does not show a "Load more" button when the page has no more rows (demo mode)', (tester) async {
    await boot(tester);
    // Demo mode's fetchAllUsers() always returns PagedResult(hasMore: false)
    // — if AdminUsersPage's `_hasMore` wiring were ever hardcoded true (or
    // wired to the wrong flag), this would be the regression that catches
    // it, since a "Load more" button that always shows but never has
    // anything more to load is a dead-end trap for the admin.
    expect(find.text('Load more'), findsNothing);
  });

  test('AdminRepository.fetchAllUsers demo mode returns a single page with hasMore false', () async {
    final page = await AdminRepository().fetchAllUsers();
    expect(page.hasMore, isFalse);
    expect(page.items, isNotEmpty);
  });

  test('AdminRepository.fetchAllUsers demo mode tolerates a non-null afterName cursor without crashing', () async {
    // Demo mode's fixed mock roster ignores pagination entirely — this
    // guards against a future refactor accidentally routing `afterName`
    // into a code path demo mode doesn't support.
    final page = await AdminRepository().fetchAllUsers(afterName: 'Zzz');
    expect(page.hasMore, isFalse);
    expect(page.items, isNotEmpty);
  });

  group('search and role filter (added for the "add search to Manage Users" request)', () {
    test('AdminRepository.fetchAllUsers demo mode filters by name/mobile search', () async {
      final byName = await AdminRepository().fetchAllUsers(search: 'Padma');
      expect(byName.items.map((p) => p.name), ['Padma Reddy']);

      final byMobile = await AdminRepository().fetchAllUsers(search: '98765 43210');
      expect(byMobile.items.map((p) => p.name), ['Lakshmi Devi']);

      final noMatch = await AdminRepository().fetchAllUsers(search: 'Nobody Named This');
      expect(noMatch.items, isEmpty);
    });

    test('AdminRepository.fetchAllUsers demo mode filters by role', () async {
      // Mock roster maps President/Secretary/Treasurer -> leader, everything
      // else -> member (see `_mockRoleMap`) — no crp/clf/admin mock members
      // exist, so this only exercises the leader/member split.
      final leaders = await AdminRepository().fetchAllUsers(role: 'leader');
      expect(leaders.items, isNotEmpty);
      expect(leaders.items.every((p) => p.role == 'leader'), isTrue);

      final members = await AdminRepository().fetchAllUsers(role: 'member');
      expect(members.items, isNotEmpty);
      expect(members.items.every((p) => p.role == 'member'), isTrue);
    });

    test('AdminRepository.fetchAllUsers demo mode combines search and role filter', () async {
      // "Lakshmi Devi" is a leader (President) — searching her name while
      // filtered to 'member' should find nothing, proving the two filters
      // are actually ANDed, not one silently overriding the other.
      final wrongRole = await AdminRepository().fetchAllUsers(search: 'Lakshmi', role: 'member');
      expect(wrongRole.items, isEmpty);

      final rightRole = await AdminRepository().fetchAllUsers(search: 'Lakshmi', role: 'leader');
      expect(rightRole.items.map((p) => p.name), ['Lakshmi Devi']);
    });

    testWidgets('typing in the search field filters the visible roster', (tester) async {
      await boot(tester);
      expect(find.text('Lakshmi Devi'), findsOneWidget);
      expect(find.text('Padma Reddy'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Padma');
      // Search is debounced 300ms so a fast typist doesn't fire a query per
      // keystroke — wait past that window before expecting the reload.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('Padma Reddy'), findsOneWidget);
      expect(find.text('Lakshmi Devi'), findsNothing);
    });

    testWidgets('selecting a role chip filters the visible roster', (tester) async {
      await boot(tester);
      // Not asserting a specific member's initial visibility here — the
      // roster is a lazily-built ListView, so which of the 12 mock rows
      // are actually built (vs merely scrolled-off) depends on the test
      // surface's height, unrelated to the filter feature under test.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Leader'));
      await tester.pumpAndSettle();

      // Only the 3 mock members mapped to 'leader' (President/Secretary/
      // Treasurer — see `_mockRoleMap`) remain; all 3 fit on screen at once
      // now that the other 9 are filtered out, so this is a reliable count.
      expect(find.byType(AppCard), findsNWidgets(3));
      expect(find.text('Lakshmi Devi'), findsOneWidget);
      expect(find.text('Anasuya'), findsNothing);
    });

    testWidgets('clearing the search field restores the full roster', (tester) async {
      await boot(tester);
      await tester.enterText(find.byType(TextField).first, 'Padma');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('Lakshmi Devi'), findsNothing);

      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Lakshmi Devi'), findsOneWidget);
      expect(find.text('Padma Reddy'), findsOneWidget);
    });
  });
}
