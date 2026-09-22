import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/marketplace/order_detail_page.dart';
import 'package:shg_saathi/repositories/marketplace_repository.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/state/app_state.dart';

/// Missing feature, called out by name in docs/SRS.md's Marketplace section:
/// buyer-initiated order cancellation ("would need a new 'cancelled' status
/// plus a stock-restore RPC" — see migration 0155). Covers the client side
/// through demo mode's real MarketplaceRepository (a genuine write into its
/// static in-memory order list, not a stub).
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  Widget harness(String orderId) => ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: MaterialApp(
          home: OrderDetailPage(orderId: orderId),
          localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );

  Future<String> placeOrder(MarketplaceRepository repo, {String productId = 'p1'}) async {
    await repo.placeOrder(productId: productId, buyerName: 'Test Buyer', buyerId: null, amount: 100);
    final orders = await repo.fetchOrdersForBuyer(null);
    return orders.first.id;
  }

  testWidgets('a new order shows Cancel Order; confirming it cancels the order and hides the button', (tester) async {
    final repo = MarketplaceRepository();
    final orderId = await placeOrder(repo);

    await tester.pumpWidget(harness(orderId));
    await tester.pumpAndSettle();

    expect(find.text('Cancel Order'), findsOneWidget);
    expect(find.text('Cancelled'), findsNothing);

    await tester.tap(find.text('Cancel Order'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel this order?'), findsOneWidget, reason: 'a confirm dialog guards this — it cannot be undone');
    await tester.tap(find.text('Cancel Order').last);
    await tester.pumpAndSettle();

    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('Cancel Order'), findsNothing, reason: 'an already-cancelled order has nothing left to cancel');
    expect(tester.takeException(), isNull);
  });

  testWidgets('dismissing the confirm dialog leaves the order untouched', (tester) async {
    final repo = MarketplaceRepository();
    final orderId = await placeOrder(repo, productId: 'p2');

    await tester.pumpWidget(harness(orderId));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel Order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Cancelled'), findsNothing);
    expect(find.text('Cancel Order'), findsOneWidget, reason: 'still cancellable — nothing happened');
    expect(tester.takeException(), isNull);
  });

  testWidgets('an order that is no longer new shows no Cancel Order button', (tester) async {
    final repo = MarketplaceRepository();
    final orderId = await placeOrder(repo, productId: 'p3');
    await repo.updateOrderStatus(orderId, 'packed');

    await tester.pumpWidget(harness(orderId));
    await tester.pumpAndSettle();

    expect(find.text('Cancel Order'), findsNothing, reason: 'this was the bug this page used to have no answer for at all — no cancellation existed for any order, at any status');
    expect(tester.takeException(), isNull);
  });

  // Missing feature: this page showed the buyer's name but never the
  // seller's — a buyer looking at her own purchase had no way to tell who
  // she'd actually bought it from without separately reopening the product
  // page. MarketOrder.sellerName is now populated (demo mode: from the mock
  // product's own sellerName, mirroring placeOrder's real live-mode embed).
  testWidgets('shows the seller\'s name on the order', (tester) async {
    final repo = MarketplaceRepository();
    final orderId = await placeOrder(repo, productId: 'p1');

    await tester.pumpWidget(harness(orderId));
    await tester.pumpAndSettle();

    expect(find.text('Seller: Lakshmi Devi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
