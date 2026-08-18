import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/marketplace/my_listings_page.dart';
import 'package:shg_saathi/repositories/marketplace_repository.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/state/app_state.dart';

/// `MarketplaceRepository.fetchMyProducts()` existed with zero UI callers
/// before this page — regression coverage for the page itself and its
/// delist/relist confirm-then-toggle flow.
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  Widget harness() => ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: MaterialApp(
          home: const MyListingsPage(),
          localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );

  testWidgets('renders every listing with edit and delist actions', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    // Demo mode's fetchMyProducts() returns the full mock catalog (see the
    // repository's own doc comment — no real seller/buyer identity split).
    expect(find.text('Handwoven Cotton Saree'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsWidgets);
    expect(find.byIcon(Icons.visibility_off_outlined), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('delisting a listing shows a confirm dialog, then flips its badge', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = MarketplaceRepository();
    await repo.addProduct(sellerId: null, name: '__TEST__ my-listings toggle', description: 'd', price: 100, stock: 1, category: 'Other');

    await tester.pumpWidget(ChangeNotifierProvider<AppState>(
      create: (_) => AppState(),
      child: MaterialApp(
        home: MyListingsPage(repository: repo),
        localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Delisted'), findsNothing);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.visibility_off_outlined).first);
    await tester.pumpAndSettle();

    expect(find.text('Delist this product?'), findsOneWidget);
    await tester.tap(find.text('Delist'));
    await tester.pumpAndSettle();

    expect(find.text('Delisted'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Relist reverses it.
    await tester.tap(find.widgetWithIcon(IconButton, Icons.visibility_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text('Relist this product?'), findsOneWidget);
    await tester.tap(find.text('Relist'));
    await tester.pumpAndSettle();

    expect(find.text('Delisted'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
