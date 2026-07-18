import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/dashboard/admin_dashboard.dart';
import 'package:shg_saathi/pages/dashboard/clf_dashboard.dart';
import 'package:shg_saathi/pages/dashboard/crp_dashboard.dart';
import 'package:shg_saathi/pages/dashboard/leader_dashboard.dart';
import 'package:shg_saathi/pages/dashboard/member_dashboard.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/state/app_state.dart';

/// All 5 dashboards used to import lib/data/*.dart mock lists directly,
/// bypassing the repository layer every other module goes through —
/// these confirm each now renders via its repository's demo-mode fallback
/// (AppAsyncBuilder loading -> data) instead of the removed direct import.
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  Future<void> pumpDashboard(WidgetTester tester, Widget dashboard) async {
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
          home: Scaffold(body: SingleChildScrollView(child: dashboard)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('MemberDashboard renders demo-mode data via repositories', (tester) async {
    await pumpDashboard(tester, const MemberDashboard());
    expect(find.text('My Savings'), findsOneWidget);
    expect(find.text('Savings Summary'), findsOneWidget);
  });

  testWidgets('LeaderDashboard renders demo-mode data via repositories', (tester) async {
    await pumpDashboard(tester, const LeaderDashboard());
    expect(find.text('Group Savings'), findsOneWidget);
    expect(find.text('SHG Health'), findsOneWidget);
  });

  testWidgets('CRPDashboard renders demo-mode data via repositories', (tester) async {
    await pumpDashboard(tester, const CRPDashboard());
    expect(find.text('SHGs Monitored'), findsOneWidget);
    expect(find.text('SHGs Under Monitoring'), findsOneWidget);
  });

  testWidgets('CLFDashboard renders demo-mode data via repositories', (tester) async {
    await pumpDashboard(tester, const CLFDashboard());
    expect(find.text('Village Orgs'), findsOneWidget);
    expect(find.text('Financial Oversight'), findsOneWidget);
  });

  testWidgets('AdminDashboard renders demo-mode data via repositories', (tester) async {
    await pumpDashboard(tester, const AdminDashboard());
    expect(find.text('Total SHGs'), findsOneWidget);
    expect(find.text('Platform Snapshot'), findsOneWidget);
  });
}
