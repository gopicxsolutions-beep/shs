import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/marketplace/marketplace_reviews_page.dart';
import 'package:shg_saathi/routes/paths.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/state/app_state.dart';

/// Missing feature: a seller with more than one listing had no way to tell
/// which product a review was even about — `fetchReviewsForSeller` embedded
/// the product only to FILTER by seller, never selecting `name`.
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  Future<void> pump(WidgetTester tester) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => const MarketplaceReviewsPage()),
      GoRoute(path: Paths.marketplaceProduct(':id'), builder: (_, state) => Scaffold(body: Text('PRODUCT ${state.pathParameters['id']}'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('each review shows which product it is about', (tester) async {
    await pump(tester);

    // Demo mode's 2 mock reviews (r1 on p1 "Handwoven Cotton Saree", r2 on p3
    // "Organic Millet Flour (1kg)") — this was the bug: neither product name
    // showed anywhere on this page before.
    expect(find.text('Handwoven Cotton Saree'), findsOneWidget);
    expect(find.text('Organic Millet Flour (1kg)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a review opens that product', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Handwoven Cotton Saree'));
    await tester.pumpAndSettle();

    expect(find.text('PRODUCT p1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
