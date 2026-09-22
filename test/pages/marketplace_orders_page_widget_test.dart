import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/marketplace/marketplace_orders_page.dart';
import 'package:shg_saathi/repositories/marketplace_repository.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/state/app_state.dart';

/// Missing feature: a buyer had no way to see her total spend across her
/// purchases, only a per-order amount in a scrollable list. Unlike the
/// seller-side revenue summary (which is live-only — demo mode's
/// `fetchOrdersForSeller` always returns `[]`), demo mode's
/// `fetchOrdersForBuyer` genuinely returns `_locallyPlaced` orders, so this
/// one IS reachable through a real widget test.
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  Widget harness() => ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: MaterialApp(
          home: const MarketplaceOrdersPage(),
          localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );

  testWidgets('My Purchases shows a spend summary for a delivered order', (tester) async {
    final repo = MarketplaceRepository();
    await repo.placeOrder(productId: 'p1', buyerName: 'Test Buyer', buyerId: null, amount: 1200);
    final orderId = (await repo.fetchOrdersForBuyer(null)).first.id;
    await repo.updateOrderStatus(orderId, 'delivered');

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.textContaining('₹1,200 spent on 1 delivered order'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // The "no summary for a merely-placed, not-yet-delivered order" case is
    // covered at the unit level instead (marketplace_orders_page_test.dart)
    // — MarketplaceRepository's `_locallyPlaced` list is static, so a
    // second widget test in this same file placing a fresh 'new' order
    // would still see THIS test's already-delivered one too.
  });
}
