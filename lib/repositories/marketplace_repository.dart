import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/marketplace.dart' as mock;
import '../models/marketplace.dart';
import '../services/supabase_service.dart';

/// Backed by `public.marketplace_products` / `_orders` / `_reviews` when
/// Supabase is configured; falls back to `lib/data/marketplace.dart`
/// otherwise. Marketplace is cross-SHG — products are browsable by any
/// authenticated member regardless of which SHG they belong to.
class MarketplaceRepository {
  SupabaseClient get _client => SupabaseService.instance.client;
  bool get _live => SupabaseService.isConfigured;

  Future<List<Product>> fetchProducts() async {
    if (!_live) return _mockProducts();
    final rows = await _client.from('marketplace_products').select('*, profiles(name)').order('created_at', ascending: false);
    return (rows as List).map((r) => Product.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<List<Product>> fetchMyProducts(String? sellerId) async {
    if (!_live || sellerId == null) return _mockProducts();
    final rows = await _client.from('marketplace_products').select('*, profiles(name)').eq('seller_id', sellerId).order('created_at', ascending: false);
    return (rows as List).map((r) => Product.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<Product?> fetchProductById(String id) async {
    if (!_live) {
      final matches = _mockProducts().where((p) => p.id == id);
      return matches.isEmpty ? null : matches.first;
    }
    final row = await _client.from('marketplace_products').select('*, profiles(name)').eq('id', id).maybeSingle();
    return row == null ? null : Product.fromMap(row);
  }

  Future<void> addProduct({
    required String? sellerId,
    required String name,
    required String description,
    required num price,
    required int stock,
    required String category,
  }) async {
    if (!_live || sellerId == null) return;
    await _client.from('marketplace_products').insert({
      'seller_id': sellerId,
      'name': name,
      'description': description,
      'price': price,
      'stock': stock,
      'category': category,
    });
  }

  Future<void> placeOrder({required String productId, required String buyerName, required String? buyerId, required num amount}) async {
    if (!_live) return;
    await _client.from('marketplace_orders').insert({
      'product_id': productId,
      'buyer_name': buyerName,
      if (buyerId != null) 'buyer_id': buyerId,
      'amount': amount,
      'status': 'new',
    });
  }

  /// Orders for products this seller listed.
  Future<List<MarketOrder>> fetchOrdersForSeller(String? sellerId) async {
    if (!_live || sellerId == null) return const [];
    final rows = await _client
        .from('marketplace_orders')
        .select('*, marketplace_products!inner(name, seller_id)')
        .eq('marketplace_products.seller_id', sellerId)
        .order('created_at', ascending: false);
    return (rows as List).map((r) => MarketOrder.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<MarketOrder?> fetchOrderById(String id) async {
    if (!_live) return null;
    final row = await _client.from('marketplace_orders').select('*, marketplace_products(name)').eq('id', id).maybeSingle();
    return row == null ? null : MarketOrder.fromMap(row);
  }

  Future<void> updateOrderStatus(String id, String status) async {
    if (!_live) return;
    await _client.from('marketplace_orders').update({'status': status}).eq('id', id);
  }

  /// Reviews across every product this seller lists.
  Future<List<Review>> fetchReviewsForSeller(String? sellerId) async {
    if (!_live || sellerId == null) return mock.marketplaceReviews.map((r) => Review(id: r.id, productId: r.productId, reviewerName: r.reviewerName, rating: r.rating, comment: r.comment)).toList();
    final rows = await _client
        .from('marketplace_reviews')
        .select('*, marketplace_products!inner(seller_id)')
        .eq('marketplace_products.seller_id', sellerId)
        .order('created_at', ascending: false);
    return (rows as List).map((r) => Review.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<List<Review>> fetchReviewsForProduct(String productId) async {
    if (!_live) return mock.marketplaceReviews.where((r) => r.productId == productId).map((r) => Review(id: r.id, productId: r.productId, reviewerName: r.reviewerName, rating: r.rating, comment: r.comment)).toList();
    final rows = await _client.from('marketplace_reviews').select().eq('product_id', productId).order('created_at', ascending: false);
    return (rows as List).map((r) => Review.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> addReview({required String productId, required String reviewerName, required int rating, required String comment}) async {
    if (!_live) return;
    await _client.from('marketplace_reviews').insert({
      'product_id': productId,
      'reviewer_name': reviewerName,
      'rating': rating,
      'comment': comment,
    });
  }

  List<Product> _mockProducts() =>
      mock.marketplaceProducts.map((p) => Product(id: p.id, sellerId: p.id, sellerName: p.sellerName, name: p.name, description: p.description, price: p.price, stock: p.stock, category: p.category)).toList();
}
