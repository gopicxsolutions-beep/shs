import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/models/marketplace.dart';
import 'package:shg_saathi/pages/marketplace/marketplace_orders_page.dart';

/// Missing feature: neither side of a purchase had any way to see a
/// running total anywhere in the app — a seller couldn't see her total
/// revenue, a buyer couldn't see her total spend, only a per-order amount
/// in a scrollable list. `marketplaceDeliveredOrdersSummary` is a top-level
/// function (not inlined in the widget) specifically so it's directly
/// testable — demo mode's `fetchOrdersForSeller` always returns `[]` (no
/// simulated second buyer exists to have ever bought from the demo
/// persona), so the "My Sales" card this backs can never actually render
/// through demo mode at all; this is the only way to verify the arithmetic
/// without a live seller account. Used identically by both the "My Sales"
/// (revenue) and "My Purchases" (spend) tabs — same arithmetic, different
/// wording around it.
MarketOrder _order({required num amount, required String status}) => MarketOrder(
      id: 'o-$amount-$status',
      productId: 'p1',
      productName: 'Test Product',
      buyerName: 'Test Buyer',
      amount: amount,
      status: status,
      orderDate: DateTime(2026, 1, 1),
    );

void main() {
  test('sums only delivered orders, ignoring new/packed/shipped/cancelled', () {
    final orders = [
      _order(amount: 100, status: 'delivered'),
      _order(amount: 250, status: 'delivered'),
      _order(amount: 500, status: 'new'),
      _order(amount: 300, status: 'packed'),
      _order(amount: 150, status: 'shipped'),
      _order(amount: 999, status: 'cancelled'),
    ];

    final result = marketplaceDeliveredOrdersSummary(orders);

    expect(result.total, 350, reason: 'only the two delivered orders (100 + 250) count as real earned revenue/spend');
    expect(result.deliveredCount, 2);
  });

  test('an empty order list has zero total, not a crash', () {
    final result = marketplaceDeliveredOrdersSummary([]);
    expect(result.total, 0);
    expect(result.deliveredCount, 0);
  });

  test('no delivered orders at all still returns zero, not null/throws', () {
    final result = marketplaceDeliveredOrdersSummary([_order(amount: 500, status: 'new')]);
    expect(result.total, 0);
    expect(result.deliveredCount, 0);
  });
}
