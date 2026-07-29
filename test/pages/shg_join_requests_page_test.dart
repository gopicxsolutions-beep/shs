import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/models/shg_join_request.dart';
import 'package:shg_saathi/models/types.dart';
import 'package:shg_saathi/pages/shg/shg_join_requests_page.dart';
import 'package:shg_saathi/repositories/shg_join_request_repository.dart';
import 'package:shg_saathi/state/app_state.dart';

class _FakeShgJoinRequestRepository extends ShgJoinRequestRepository {
  final List<ShgJoinRequest> requests;
  final List<({String requestId, bool approve, bool asLeader})> decideCalls = [];
  _FakeShgJoinRequestRepository(this.requests);

  @override
  Future<List<ShgJoinRequest>> fetchPendingForShg(String? shgId) async => requests;

  @override
  Future<void> decide(String requestId, bool approve, {bool asLeader = false}) async {
    decideCalls.add((requestId: requestId, approve: approve, asLeader: asLeader));
  }
}

/// Regression coverage for the onboarding redesign's approve-as-leader
/// option (migration 0116): the RPC restricts `p_as_leader: true` to staff
/// (crp/clf/admin) — a peer leader reviewing her own SHG's queue can only
/// approve as member or reject. The client must never dangle a button the
/// backend would reject, so this asserts the two viewer types see different
/// controls.
void main() {
  final sampleRequest = ShgJoinRequest(id: 'req-1', memberId: 'm1', memberName: 'Anjali Kumari', shgId: 'shg-1', status: 'pending', requestedAt: DateTime(2026, 1, 1));

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<_FakeShgJoinRequestRepository> boot(WidgetTester tester, Role role) async {
    final appState = AppState();
    await appState.setRole(role);
    final repo = _FakeShgJoinRequestRepository([sampleRequest]);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          home: ShgJoinRequestsPage(repository: repo),
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
    return repo;
  }

  testWidgets('a leader viewing her own SHG queue sees Approve/Reject but never Approve as Leader', (tester) async {
    await boot(tester, Role.leader);

    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
    expect(find.text('Approve as Leader'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a staff viewer sees Approve as Leader in addition to Approve/Reject', (tester) async {
    await boot(tester, Role.admin);

    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
    expect(find.text('Approve as Leader'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping Approve as Leader forwards asLeader:true to the repository; plain Approve forwards asLeader:false', (tester) async {
    final repo = await boot(tester, Role.admin);

    await tester.tap(find.text('Approve as Leader'));
    await tester.pumpAndSettle();

    expect(repo.decideCalls, hasLength(1));
    expect(repo.decideCalls.single.requestId, 'req-1');
    expect(repo.decideCalls.single.approve, isTrue);
    expect(repo.decideCalls.single.asLeader, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping plain Approve forwards asLeader:false even for a staff viewer', (tester) async {
    final repo = await boot(tester, Role.admin);

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(repo.decideCalls, hasLength(1));
    expect(repo.decideCalls.single.approve, isTrue);
    expect(repo.decideCalls.single.asLeader, isFalse);
    expect(tester.takeException(), isNull);
  });
}
