import '../l10n/gen/app_localizations.dart';

/// `new`/`packed`/`shipped`/`delivered` were shown as raw DB strings
/// everywhere an order's status appears — unlike every sibling status-
/// bearing module (loans, savings, payments, schemes, support tickets),
/// which all already have a dedicated localized status-label helper.
String marketplaceOrderStatusLabel(String status, AppLocalizations l10n) => switch (status) {
      'new' => l10n.marketplaceOrderStatusNew,
      'packed' => l10n.marketplaceOrderStatusPacked,
      'shipped' => l10n.marketplaceOrderStatusShipped,
      'delivered' => l10n.marketplaceOrderStatusDelivered,
      _ => status,
    };

/// Product categories (`marketplace_home_page.dart`'s filter chips,
/// `add_product_page.dart`'s picker, and a listing's own detail badge) were
/// the one enum-like field in this module never given the same treatment
/// as order status above — shown as raw English on the most member-facing
/// screens in the app (round 189/iteration 17 audit).
String marketplaceCategoryLabel(String category, AppLocalizations l10n) => switch (category) {
      'Handicrafts' => l10n.marketplaceCategoryHandicrafts,
      'Tailoring' => l10n.marketplaceCategoryTailoring,
      'Food' => l10n.marketplaceCategoryFood,
      'Agriculture' => l10n.marketplaceCategoryAgriculture,
      'Other' => l10n.marketplaceCategoryOther,
      _ => category,
    };

/// Mirrors a row in `public.marketplace_products` (joined with seller name).
class Product {
  final String id;
  final String sellerId;
  final String sellerName;
  final String name;
  final String? description;
  final num price;
  final int stock;
  final String? category;
  final String? imageUrl;

  const Product({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    required this.name,
    this.description,
    required this.price,
    required this.stock,
    this.category,
    this.imageUrl,
  });

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: map['id'] as String,
        sellerId: map['seller_id'] as String,
        sellerName: (map['profiles'] as Map<String, dynamic>?)?['name'] as String? ?? 'Seller',
        name: map['name'] as String,
        description: map['description'] as String?,
        price: map['price'] as num,
        stock: map['stock'] as int? ?? 0,
        category: map['category'] as String?,
        imageUrl: map['image_url'] as String?,
      );
}

/// Mirrors a row in `public.marketplace_orders`.
class MarketOrder {
  final String id;
  final String productId;
  final String productName;
  final String? sellerId;
  final String buyerName;
  final num amount;
  final String status; // new | packed | shipped | delivered
  final DateTime orderDate;

  const MarketOrder({
    required this.id,
    required this.productId,
    required this.productName,
    this.sellerId,
    required this.buyerName,
    required this.amount,
    required this.status,
    required this.orderDate,
  });

  factory MarketOrder.fromMap(Map<String, dynamic> map) => MarketOrder(
        id: map['id'] as String,
        productId: map['product_id'] as String,
        productName: (map['marketplace_products'] as Map<String, dynamic>?)?['name'] as String? ?? 'Product',
        sellerId: (map['marketplace_products'] as Map<String, dynamic>?)?['seller_id'] as String?,
        buyerName: map['buyer_name'] as String,
        amount: map['amount'] as num,
        status: map['status'] as String,
        orderDate: DateTime.parse(map['order_date'] as String),
      );
}

/// Mirrors a row in `public.marketplace_reviews`.
class Review {
  final String id;
  final String productId;
  final String? reviewerId;
  final String reviewerName;
  final int rating;
  final String? comment;

  const Review({required this.id, required this.productId, this.reviewerId, required this.reviewerName, required this.rating, this.comment});

  factory Review.fromMap(Map<String, dynamic> map) => Review(
        id: map['id'] as String,
        productId: map['product_id'] as String,
        reviewerId: map['reviewer_id'] as String?,
        reviewerName: map['reviewer_name'] as String,
        rating: map['rating'] as int,
        comment: map['comment'] as String?,
      );
}
