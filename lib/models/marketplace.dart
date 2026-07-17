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

  const Product({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    required this.name,
    this.description,
    required this.price,
    required this.stock,
    this.category,
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
      );
}

/// Mirrors a row in `public.marketplace_orders`.
class MarketOrder {
  final String id;
  final String productId;
  final String productName;
  final String buyerName;
  final num amount;
  final String status; // new | packed | shipped | delivered
  final DateTime orderDate;

  const MarketOrder({
    required this.id,
    required this.productId,
    required this.productName,
    required this.buyerName,
    required this.amount,
    required this.status,
    required this.orderDate,
  });

  factory MarketOrder.fromMap(Map<String, dynamic> map) => MarketOrder(
        id: map['id'] as String,
        productId: map['product_id'] as String,
        productName: (map['marketplace_products'] as Map<String, dynamic>?)?['name'] as String? ?? 'Product',
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
  final String reviewerName;
  final int rating;
  final String? comment;

  const Review({required this.id, required this.productId, required this.reviewerName, required this.rating, this.comment});

  factory Review.fromMap(Map<String, dynamic> map) => Review(
        id: map['id'] as String,
        productId: map['product_id'] as String,
        reviewerName: map['reviewer_name'] as String,
        rating: map['rating'] as int,
        comment: map['comment'] as String?,
      );
}
