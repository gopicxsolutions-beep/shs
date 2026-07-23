import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/meetings/meeting_mom_page.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/state/app_state.dart';

/// Regression coverage for `MeetingActionItem.ownerId` being permanently
/// null — `_addActionItem()` never passed one to `MeetingRepository.
/// addActionItem()`, so `canToggle = isLeaderOrStaff || item.ownerId ==
/// currentMemberId` could never be satisfied by a plain member, meaning she
/// could never mark her own assigned task done. Fixed by adding a real
/// member-picker ("Assign to") sourced from the same SHG roster
/// `MeetingRepository.fetchRoster()` already exposes.
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  group('canToggleActionItem (pure gate logic)', () {
    test('a plain member cannot toggle an item with no owner (the exact bug this fix closes)', () {
      expect(canToggleActionItem(isLeaderOrStaff: false, ownerId: null, currentMemberId: 'm4'), isFalse);
    });

    test('a plain member CAN toggle an item explicitly assigned to her', () {
      expect(canToggleActionItem(isLeaderOrStaff: false, ownerId: 'm4', currentMemberId: 'm4'), isTrue);
    });

    test('a plain member cannot toggle an item assigned to a different member', () {
      expect(canToggleActionItem(isLeaderOrStaff: false, ownerId: 'm5', currentMemberId: 'm4'), isFalse);
    });

    test('a leader/staff account can always toggle, regardless of owner', () {
      expect(canToggleActionItem(isLeaderOrStaff: true, ownerId: null, currentMemberId: 'm4'), isTrue);
      expect(canToggleActionItem(isLeaderOrStaff: true, ownerId: 'm5', currentMemberId: 'm4'), isTrue);
    });
  });

  Future<void> boot(WidgetTester tester, {required String role, String meetingId = 'mt1'}) async {
    SharedPreferences.setMockInitialValues({
      'shg_session_started': true,
      'shg_authenticated': true,
      'shg_role': role,
    });
    final appState = AppState();
    await appState.init();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(home: MeetingMomPage(meetingId: meetingId), localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], supportedLocales: AppLocalizations.supportedLocales, ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a plain member sees no "Assign to" picker or add-task field', (tester) async {
    await boot(tester, role: 'member');

    expect(find.text('Assign to'), findsNothing);
    expect(find.widgetWithText(TextField, 'Add a task…'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a leader can assign a new action item to a specific SHG member, and it is created with that ownerId (surfaced via "Assigned to <name>")', (tester) async {
    await boot(tester, role: 'leader');

    // The picker defaults to Unassigned.
    expect(find.text('Assign to'), findsOneWidget);
    expect(find.text('Unassigned'), findsWidgets);

    // Open the dropdown and pick a real roster member (same roster
    // `shg_members_page.dart`/`meeting_attendance_page.dart` use).
    await tester.tap(find.text('Unassigned').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lakshmi Devi').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Add a task…'), '__TEST__ collect due savings');
    await tester.tap(find.byTooltip('Add action item'));
    await tester.pumpAndSettle();

    expect(find.text('__TEST__ collect due savings'), findsOneWidget);
    expect(find.textContaining('Assigned to Lakshmi Devi'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // The picker resets to Unassigned for the next item rather than
    // silently carrying the previous assignee over.
    expect(find.text('Unassigned'), findsWidgets);
  });

  testWidgets('a leader can still toggle a newly-assigned action item done (canToggle is never blocked for staff)', (tester) async {
    await boot(tester, role: 'leader');

    await tester.enterText(find.widgetWithText(TextField, 'Add a task…'), '__TEST__ unassigned task');
    await tester.tap(find.byTooltip('Add action item'));
    await tester.pumpAndSettle();

    final tile = tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, '__TEST__ unassigned task'));
    expect(tile.value, isFalse);
    expect(tile.onChanged, isNotNull);

    await tester.tap(find.widgetWithText(CheckboxListTile, '__TEST__ unassigned task'));
    await tester.pumpAndSettle();

    final toggled = tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, '__TEST__ unassigned task'));
    expect(toggled.value, isTrue);
    expect(tester.takeException(), isNull);
  });
}
