import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/admin/admin_monitoring_page.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/widgets/stat_card.dart';

/// Regression coverage for the "AI Advisor Blocks (7d)" / "Members Flagged
/// (7d)" stats added to the Admin Monitoring page — real counts from
/// `AdminRepository.fetchAiAdvisorModerationStats()` (`ai_advisor_logs`'
/// `blocked`/`block_reason` columns, migration 0044), closing
/// docs/AI_MODULES.md §6's disclosed "no anomaly/abuse monitoring on the
/// logs" gap. Demo mode has no real moderation pipeline to have blocked
/// anything, so this only exercises the honest "zero" path — see
/// test/repositories/admin_dashboard_stats_repository_test.dart for direct
/// repository-level coverage.
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  Future<void> boot(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminMonitoringPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders both AI moderation stats with real (zero) demo-mode counts, not a fabricated figure', (tester) async {
    await boot(tester);
    expect(find.text('AI Advisor Blocks (7d)'), findsOneWidget);
    expect(find.text('Members Flagged (7d)'), findsOneWidget);
    // Both cards genuinely read zero in demo mode -- two separate StatCards
    // each showing '0', not one shared value.
    expect(find.text('0'), findsNWidgets(2));
  });

  testWidgets('the two new moderation stat cards render at the same paired width as the existing stat rows, not full-bleed', (tester) async {
    // Regression: an earlier version placed the new stat as a single bare
    // StatCard directly in the ListView (no Row/Expanded) instead of paired
    // like every other stat row on this page -- a ListView's SliverList
    // gives a bare child TIGHT constraints equal to the full viewport width,
    // so it rendered at roughly double the width of its paired siblings
    // (measured 768px vs 378px), breaking the page's 2-column stat grid.
    await boot(tester);
    final blocksCardSize = tester.getSize(find.ancestor(of: find.text('AI Advisor Blocks (7d)'), matching: find.byType(StatCard)));
    final totalUsersCardSize = tester.getSize(find.ancestor(of: find.text('Total Users'), matching: find.byType(StatCard)));
    expect(blocksCardSize.width, closeTo(totalUsersCardSize.width, 1.0), reason: 'the new stat card must be paired to the same half-width as the existing stat cards, not full-bleed');
  });

  testWidgets('renders without throwing alongside the existing system-health stats', (tester) async {
    await boot(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Total Users'), findsOneWidget);
    expect(find.text('Total SHGs'), findsOneWidget);
  });
}
