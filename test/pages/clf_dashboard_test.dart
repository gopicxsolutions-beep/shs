import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/dashboard/clf_dashboard.dart';
import 'package:shg_saathi/services/supabase_service.dart';

/// Round 168 (SRS.md's round 135 gap note) — CLF's counterpart to
/// crp_dashboard_test.dart. CLF shares CRP's `is_staff()` surface almost
/// everywhere (see clf_dashboard.dart's own doc comment), and this stat
/// was no exception.
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  testWidgets('shows the same platform-wide training completion figure the Admin dashboard already computes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: SingleChildScrollView(child: CLFDashboard())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Training Completion'), findsOneWidget);
    // lib/data/training.dart's courses carry progress [100, 60, 30, 0, 0,
    // 100] -> average 48.33, rounds to 48.
    expect(find.text('48%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
