import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/models/shg_join_request.dart';
import 'package:shg_saathi/pages/auth/shg_approval_pending_page.dart';
import 'package:shg_saathi/pages/shg/shg_join_requests_page.dart';
import 'package:shg_saathi/repositories/shg_join_request_repository.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/state/app_state.dart';

class _FixedRequestRepository extends ShgJoinRequestRepository {
  _FixedRequestRepository(this._request);
  final ShgJoinRequest? _request;
  @override
  Future<ShgJoinRequest?> fetchMine(String? memberId) async => _request;
}

/// The SHG join-approval workflow only activates in live (Supabase-
/// configured) mode — demo mode's repositories short-circuit to empty/null
/// so as not to disturb the existing demo flow the rest of the app relies
/// on for UI testing. That means these two new pages can't be exercised
/// through the usual flutter-web-demo browser technique (which forces
/// SupabaseService.isConfigured = false), and live-mode testing needs a
/// real phone OTP session this environment can't produce. These widget
/// tests are the next best thing: they confirm both pages render their
/// demo-mode (empty-state) branch without throwing, using the same
/// AppAsyncBuilder plumbing every other module's tests already cover.
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  // Demo mode's ShgJoinRequestRepository.fetchMine() always returns null (no
  // backing table) — same as a live account whose join request genuinely
  // doesn't exist. Gap-hunt iteration 28 found and fixed a real bug where
  // that exact case fell into the same "Waiting for approval" copy as a
  // genuinely pending request; the corrected, intentional behavior for a
  // null request is the distinct "no SHG selected yet" state instead — see
  // shg_approval_pending_page.dart's `noRequest` branch.
  testWidgets('ShgApprovalPendingPage renders the no-request state without a live request', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: _localizedApp(const ShgApprovalPendingPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No SHG selected yet'), findsOneWidget);
    expect(find.text('Choose an SHG'), findsOneWidget);
  });

  // Live-audited (2026-09-22) real bug: a member whose SHG membership was
  // later removed by an admin OUTSIDE the join-request flow (e.g. `Admin >
  // Manage Users > Assign SHG`, which never touches `shg_join_requests` at
  // all) keeps her old 'approved' request row forever. The router still
  // sends her here (`needsShgApproval`: role='member', shgId=null), and
  // before this fix the page had no explicit branch for `status == 'approved'`
  // — it silently fell into the same "Waiting for approval" copy as a
  // genuine first-time pending request, telling an already-vetted member
  // (with real savings/loan/attendance history) to keep waiting for a
  // decision that was already made and then undone.
  testWidgets('a previously-approved-then-removed member sees a distinct "no longer linked" state, not "Waiting for approval"', (tester) async {
    final staleApproved = ShgJoinRequest(id: 'req-old', memberId: 'm1', shgId: 'shg-1', shgName: 'Testing Group', status: 'approved', requestedAt: DateTime(2026, 7, 29));
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: _localizedApp(ShgApprovalPendingPage(repository: _FixedRequestRepository(staleApproved))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Waiting for approval'), findsNothing, reason: 'this was the bug: an already-decided request must not read as still-pending');
    expect(find.text('No longer linked to an SHG'), findsOneWidget);
    expect(find.text('Choose an SHG'), findsOneWidget);
    // Neither Check Status nor Withdraw make sense for an already-decided
    // request — Check Status can never change anything, and Withdraw would
    // silently no-op (see ShgJoinRequestRepository.withdraw's own fix).
    expect(find.text('Check Status'), findsNothing);
    expect(find.text('Withdraw request'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a genuinely pending request still shows "Waiting for approval" with Check Status and Withdraw', (tester) async {
    // This state renders the SHG card plus three buttons (Check Status,
    // Choose Different SHG, Withdraw) on top of Sign Out — taller than the
    // default 800x600 test surface fits without overflowing.
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final pending = ShgJoinRequest(id: 'req-new', memberId: 'm1', shgId: 'shg-1', shgName: 'Testing Group', status: 'pending', requestedAt: DateTime(2026, 9, 1));
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: _localizedApp(ShgApprovalPendingPage(repository: _FixedRequestRepository(pending))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Waiting for approval'), findsOneWidget);
    expect(find.text('Check Status'), findsOneWidget);
    expect(find.text('Withdraw request'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ShgJoinRequestsPage renders the empty state without any live requests', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: _localizedApp(const ShgJoinRequestsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No pending join requests'), findsOneWidget);
  });
}

MaterialApp _localizedApp(Widget home) => MaterialApp(
      home: home,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
