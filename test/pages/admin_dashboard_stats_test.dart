import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/dashboard/admin_dashboard.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/state/app_state.dart';

/// Regression coverage for replacing AdminDashboard's fabricated stats
/// (`_trainingCompletion`, `_pendingVerificationCount`, `_recentActivity` —
/// static constants that never changed no matter what happened on the
/// platform) with real values computed by
/// `AdminRepository.fetchDashboardStats()`. See
/// test/repositories/admin_dashboard_stats_repository_test.dart for direct
/// coverage of the computation itself; this file checks the real numbers
/// actually reach the screen.
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  Future<void> pumpDashboard(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: const AdminDashboard())),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Training Completion is computed from mock course progress (48%), not the old fixed 87%', (tester) async {
    await pumpDashboard(tester);
    // lib/data/training.dart's courses carry progress [100, 60, 30, 0, 0,
    // 100] -> average 48.33, rounds to 48.
    expect(find.text('48%'), findsOneWidget);
    expect(find.text('87%'), findsNothing);
  });

  testWidgets('pending-review banner shows a real scheme-application count, not the old fixed KYC copy', (tester) async {
    await pumpDashboard(tester);
    // lib/data/schemes.dart has exactly 2 schemes still applied/under_review
    // (PMEGP, MUDRA) — the same real queue SchemeApplicationsReviewPage acts
    // on, not a fabricated "accounts pending verification" count.
    expect(find.text('2 scheme applications pending review'), findsOneWidget);
    expect(find.textContaining('accounts pending verification'), findsNothing);
    expect(find.textContaining('Aadhaar'), findsNothing);
  });

  testWidgets('System Uptime is now backed by a real (if narrowly-scoped) heartbeat status, not a hardcoded placeholder', (tester) async {
    // Regression: this stat used to be a hardcoded `'N/A'` constant with
    // "Not live-monitored" as static trend text, never backed by any real
    // data. It's now AdminRepository.fetchSystemHeartbeatStatus() — demo
    // mode reports a synthetic healthy heartbeat (see that method's own doc
    // comment), rendered as "Healthy" with a "Heartbeat: just now" trend.
    await pumpDashboard(tester);
    expect(find.text('Healthy'), findsOneWidget);
    expect(find.text('Heartbeat: Just now'), findsOneWidget);
    expect(find.text('N/A'), findsNothing);
    expect(find.text('Not live-monitored'), findsNothing);
    expect(find.text('All services normal'), findsNothing);
    expect(find.text('99.98%'), findsNothing);
  });

  testWidgets('Recent System Activity is assembled from real mock records, not the old static 3-row feed', (tester) async {
    await pumpDashboard(tester);
    expect(find.textContaining('Scheduled backup completed'), findsNothing);
    expect(find.textContaining('Scheme details updated'), findsNothing);
    // At least one row should be a real derived "Document uploaded —" or
    // "New user registered —" entry (see AdminRepository.fetchDashboardStats'
    // demo branch) — both demo and live modes now share one phrasing per
    // AdminActivityKind, formatted through AppLocalizations in
    // admin_dashboard.dart's _activityMessage() rather than baked into the
    // repository layer as an un-localizable string.
    final hasRealActivity = find.textContaining('Document uploaded —').evaluate().isNotEmpty || find.textContaining('New user registered —').evaluate().isNotEmpty;
    expect(hasRealActivity, isTrue);
  });
}
