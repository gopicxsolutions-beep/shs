import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shg_saathi/data/marketplace.dart' as mock;
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/marketplace/product_detail_page.dart';
import 'package:shg_saathi/repositories/marketplace_repository.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/state/app_state.dart';

/// Coverage for the seller-payment-details / "Pay via UPI" feature added to
/// this page. Doesn't assert a real external UPI app actually opens —
/// `url_launcher`'s platform channel is unmocked under `flutter test`, the
/// same documented limitation as this app's camera/mic features — only
/// that the button renders/hides correctly and tapping it doesn't throw.
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });
  tearDown(() {
    MarketplaceRepository.debugProductsOverride = null;
  });

  Widget harness(String productId) => ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: MaterialApp(
          home: ProductDetailPage(productId: productId),
          localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );

  testWidgets('Pay via UPI is hidden when the product has no UPI ID', (tester) async {
    // Mock product 'p2' (Rajeshwari's blouse) has no upiId set.
    await tester.pumpWidget(harness('p2'));
    await tester.pumpAndSettle();

    expect(find.text('Pay via UPI'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pay via UPI shows the seller\'s UPI ID and note, and can be tapped', (tester) async {
    // Taller than the default 800x600 test surface — the quantity stepper
    // (added alongside the "Pay via UPI" card) pushes this button below the
    // default viewport, which a plain `tester.tap` (unlike a real tap
    // gesture) doesn't auto-scroll to first.
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Mock product 'p1' (Lakshmi Devi's saree) has upiId/paymentNote set.
    await tester.pumpWidget(harness('p1'));
    await tester.pumpAndSettle();

    expect(find.text('Payment Details'), findsOneWidget);
    expect(find.text('UPI ID: lakshmidevi@upi'), findsOneWidget);
    expect(find.text('Cash on delivery also accepted'), findsOneWidget);
    expect(find.text('Pay via UPI'), findsOneWidget);

    await tester.tap(find.text('Pay via UPI'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('a delisted product shows a Delisted badge and disables Place Order', (tester) async {
    MarketplaceRepository.debugProductsOverride = const [
      mock.ProductMock(id: 'delisted-1', sellerName: 'Test Seller', name: 'A Delisted Product', description: 'no longer available', price: 100, stock: 5, category: 'Other', upiId: 'seller@upi', isActive: false),
    ];

    await tester.pumpWidget(harness('delisted-1'));
    await tester.pumpAndSettle();

    expect(find.text('Delisted'), findsOneWidget);
    // Delisted takes priority over any purchase action, including UPI pay.
    expect(find.text('Pay via UPI'), findsNothing);
    final placeOrderButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Place Order'));
    expect(placeOrderButton.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  // User-reported gap: buying anything in the marketplace had no way to ask
  // for more than 1 unit at all — no quantity concept existed anywhere in
  // this stack (not the UI, not the order table, not the RPC — see
  // migration 0153). These cover the new quantity stepper end to end
  // through demo mode's real placeOrder() (a genuine write into
  // MarketplaceRepository's static in-memory order list — not a stub).
  group('quantity stepper', () {
    const stocked = mock.ProductMock(id: 'qty-1', sellerName: 'Test Seller', name: 'Stocked Item', description: 'plenty available', price: 100, stock: 3, category: 'Other');

    // `find.byTooltip` matches the wrapping `Tooltip`, not the `IconButton`
    // itself — go through the icon to reach the actual button for tapping
    // or reading `onPressed`.
    Finder decreaseButton() => find.widgetWithIcon(IconButton, Icons.remove_circle_outline_rounded);
    Finder increaseButton() => find.widgetWithIcon(IconButton, Icons.add_circle_outline_rounded);

    testWidgets('starts at 1, decrease is disabled, increase raises it and shows a running total', (tester) async {
      MarketplaceRepository.debugProductsOverride = const [stocked];
      await tester.pumpWidget(harness('qty-1'));
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget, reason: 'default quantity');
      expect(tester.widget<IconButton>(decreaseButton()).onPressed, isNull, reason: 'cannot go below 1');
      expect(find.textContaining('Total:'), findsNothing, reason: 'no separate total needed at quantity 1 — it just repeats the unit price');

      await tester.tap(increaseButton());
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Total: ₹200'), findsOneWidget);

      await tester.tap(increaseButton());
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Total: ₹300'), findsOneWidget);
      // Stock is exactly 3 — increase must now be disabled, not silently
      // let her ask for more than exists.
      expect(tester.widget<IconButton>(increaseButton()).onPressed, isNull);

      expect(tester.takeException(), isNull);
    });

    testWidgets('placing an order sends the picked quantity and the TOTAL amount, then resets to 1', (tester) async {
      MarketplaceRepository.debugProductsOverride = const [stocked];
      await tester.pumpWidget(harness('qty-1'));
      await tester.pumpAndSettle();

      await tester.tap(increaseButton());
      await tester.pumpAndSettle();
      await tester.tap(increaseButton());
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);

      await tester.tap(find.text('Place Order'));
      await tester.pumpAndSettle();

      final placed = (await MarketplaceRepository().fetchOrdersForBuyer(null)).first;
      expect(placed.productId, 'qty-1');
      expect(placed.quantity, 3, reason: 'this was the bug: quantity was never sent anywhere, always defaulting to 1');
      expect(placed.amount, 300, reason: 'amount must be the TOTAL for 3 units (100 x 3), not the bare unit price');

      // Back to 1 for whatever she buys next.
      expect(find.text('1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an out-of-stock product shows no quantity stepper at all', (tester) async {
      MarketplaceRepository.debugProductsOverride = const [
        mock.ProductMock(id: 'qty-oos', sellerName: 'Test Seller', name: 'Sold Out Item', description: 'none left', price: 50, stock: 0, category: 'Other'),
      ];
      await tester.pumpWidget(harness('qty-oos'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Increase quantity'), findsNothing);
      expect(find.byTooltip('Decrease quantity'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
