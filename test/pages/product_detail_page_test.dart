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
}
