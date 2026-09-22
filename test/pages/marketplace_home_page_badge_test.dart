import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shg_saathi/data/marketplace.dart' as mock;
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/marketplace/marketplace_home_page.dart';
import 'package:shg_saathi/repositories/marketplace_repository.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/state/app_state.dart';

/// Missing feature: a seller had no way to know a new order arrived at all —
/// `fetchPendingSalesCount` (live-mode only; see its own doc comment for
/// why demo mode can't simulate a real seller/buyer sale) backs a badge on
/// the Orders tile, using `IconTile`'s own `badge` support that had zero
/// callers anywhere in the app before this. Demo mode can't drive a nonzero
/// count (no real seller/buyer split to have "sold" anything to), so this
/// covers the page renders correctly with none — the actual nonzero-count
/// query shape is verified directly against the live database instead (see
/// docs/DEVELOPMENT_PROGRESS.md for that round's entry).
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  testWidgets('renders with no pending-orders badge in demo mode, no exception', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: MaterialApp(
          home: const MarketplaceHomePage(),
          localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Orders'), findsOneWidget);
    // The badge is a small circular Container positioned over the tile's
    // icon — absent entirely (not "0") whenever the count is 0, same
    // "hidden rather than shown as zero" convention used elsewhere in this
    // app (e.g. the dashboards' pending-join-request banners).
    expect(find.text('0'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // Marketplace audit finding: `fetchProducts()` deliberately still returns
  // a seller her own delisted listing (and every delisted listing to staff —
  // RLS's SELECT policy permits both, for self-management/moderation), but
  // the browse grid never said so — a delisted item looked exactly like a
  // live one until tapping through to the product page's own badge.
  testWidgets('a delisted product shows a Delisted badge in the browse grid', (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    MarketplaceRepository.debugProductsOverride = const [
      mock.ProductMock(id: 'grid-active', sellerName: 'Test Seller', name: 'Still Live Item', description: 'd', price: 100, stock: 5, category: 'Other'),
      mock.ProductMock(id: 'grid-delisted', sellerName: 'Test Seller', name: 'Delisted Item', description: 'd', price: 100, stock: 5, category: 'Other', isActive: false),
    ];
    addTearDown(() => MarketplaceRepository.debugProductsOverride = null);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: MaterialApp(
          home: const MarketplaceHomePage(),
          localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Delisted'), findsOneWidget, reason: 'this was the bug: no badge at all, indistinguishable from the still-live item');
    expect(find.text('Still Live Item'), findsOneWidget);
    expect(find.text('Delisted Item'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Missing feature: the browse grid never showed any rating at all — a
  // buyer comparing listings had to open each one individually to see if
  // it had good reviews. `Product.avgRating`/`reviewCount` are demo-mode
  // computed from mock.marketplaceReviews (real product 'p1' has one
  // 5-star review baked into that fixture data); live mode's actual
  // trigger-maintained aggregate is verified directly against the real
  // database instead (probe15_rating_stats.sql).
  testWidgets('the browse grid shows a star rating chip for a reviewed product', (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: MaterialApp(
          home: const MarketplaceHomePage(),
          localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('5.0'), findsOneWidget, reason: 'p1 has exactly one 5-star mock review');
    expect(tester.takeException(), isNull);
  });
}
