import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/auth/shg_approval_pending_page.dart';
import 'package:shg_saathi/pages/shg/shg_join_requests_page.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/state/app_state.dart';

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
