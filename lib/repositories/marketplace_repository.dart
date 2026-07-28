import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/marketplace.dart' as mock;
import '../models/marketplace.dart';
import '../models/types.dart';
import '../services/supabase_service.dart';

/// Backed by `public.marketplace_products` / `_orders` / `_reviews` when
/// Supabase is configured; falls back to `lib/data/marketplace.dart`
/// otherwise. Marketplace is cross-SHG — products are browsable by any
/// authenticated member regardless of which SHG they belong to.
class MarketplaceRepository {
  SupabaseClient get _client => SupabaseService.instance.client;
  bool get _live => SupabaseService.isConfigured;

  // Demo mode has no backing table, so a placed order would otherwise
  // vanish the instant the orders list reloads — track it here so it
  // survives for the rest of the session, mirroring
  // AnnouncementRepository._locallyRead. There's no real seller/buyer
  // identity split in demo mode (both collapse to the one demo persona),
  // so every locally-placed order simply shows up in the one Orders inbox.
  static final List<MarketOrder> _locallyPlaced = [];

  // Demo mode has no backing table, so a listed product would otherwise
  // vanish the instant the catalog reloads — track it here so it survives
  // for the rest of the session, mirroring AnnouncementRepository._locallyRead.
  static final List<Product> _locallyAddedProducts = [];

  // Test-only seam (null by default, so every existing test keeps seeing
  // the exact short mock.marketplaceProducts it always has).
  // test/routes/long_content_stress_test.dart sets this to exercise a
  // realistic long product name/description at a normal viewport, then
  // resets it — no change to lib/data/marketplace.dart's shared mock
  // records themselves.
  static List<mock.ProductMock>? debugProductsOverride;

  Future<List<Product>> fetchProducts() async {
    if (!_live) return [..._locallyAddedProducts.reversed, ..._mockProducts()];
    // Cross-SHG: every seller on the platform lists into this one catalog
    // (see class doc comment), with no search/filter on MarketplaceHomePage
    // to narrow it — unlike a single SHG's member/loan lists (bounded to
    // ~10-30 rows), this grows with total sellers × products across the
    // whole platform, not any one group's size. Previously had no `.limit()`
    // at all, so the query (and its payload) would grow completely
    // unbounded as the marketplace matures. Capped at a generous 500 rather
    // than left unbounded — newest-first ordering means it's the oldest,
    // least-recently-listed products that would fall past the cap first.
    final rows = await _client.from('marketplace_products').select('*, profiles(name)').order('created_at', ascending: false).limit(500);
    return (rows as List).map((r) => Product.fromMap(r as Map<String, dynamic>)).toList();
  }

  // No current call site (kept for a future "My Listings" screen) — the
  // demo branch ignores [sellerId] on purpose, not by omission: demo mode
  // has no real seller/buyer identity split (see this class's own doc
  // comment), so every demo-mode product is already "this persona's own,"
  // matching how `placeOrder()`'s demo branch makes the same simplification.
  Future<List<Product>> fetchMyProducts(String? sellerId) async {
    if (!_live) return [..._locallyAddedProducts.reversed, ..._mockProducts()];
    if (sellerId == null) return [];
    final rows = await _client.from('marketplace_products').select('*, profiles(name)').eq('seller_id', sellerId).order('created_at', ascending: false);
    return (rows as List).map((r) => Product.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<Product?> fetchProductById(String id) async {
    if (!_live) {
      final matches = [..._locallyAddedProducts, ..._mockProducts()].where((p) => p.id == id);
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
    String? imageUrl,
  }) async {
    if (!_live) {
      _locallyAddedProducts.add(Product(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        sellerId: sellerId ?? 'me',
        sellerName: defaultUser.name,
        name: name,
        description: description,
        price: price,
        stock: stock,
        category: category,
        imageUrl: imageUrl,
      ));
      return;
    }
    if (sellerId == null) return;
    await _client.from('marketplace_products').insert({
      'seller_id': sellerId,
      'name': name,
      'description': description,
      'price': price,
      'stock': stock,
      'category': category,
      'image_url': ?imageUrl,
    });
  }

  /// Uploads a picked image's bytes to the `product-images` bucket under
  /// this seller's own folder (`{sellerId}/{filename}`) — the folder
  /// convention `0005_storage_buckets.sql`'s RLS keys off of
  /// (`(storage.foldername(name))[1] = auth.uid()`). Unlike `shg-documents`,
  /// this bucket is public-read, so the returned URL is a stable, permanent
  /// public URL rather than a short-lived signed one — no separate
  /// "get download URL" step is needed to display it. The bucket enforces a
  /// 5 MiB size cap and a JPEG/PNG/WEBP allow-list server-side
  /// (`0028_storage_bucket_size_and_type_limits.sql`) — a rejected upload
  /// throws a `StorageException`, surfaced by the caller as a friendly error.
  Future<String> uploadProductImage({required String sellerId, required Uint8List bytes, required String fileName, required String contentType}) async {
    final path = '$sellerId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await _client.storage.from('product-images').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: contentType));
    return _client.storage.from('product-images').getPublicUrl(path);
  }

  // [buyerName]/[amount] are only used in demo mode (no backing table to
  // verify anything against). In live mode both the order's buyer identity
  // and its amount are always resolved server-side by
  // `place_marketplace_order` at the moment of purchase — see the comment
  // below — never these caller-supplied values.
  Future<void> placeOrder({required String productId, required String buyerName, required String? buyerId, required num amount}) async {
    if (!_live) {
      final matches = _mockProducts().where((p) => p.id == productId);
      _locallyPlaced.add(MarketOrder(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        productId: productId,
        productName: matches.isEmpty ? productId : matches.first.name,
        buyerName: buyerName,
        amount: amount,
        status: 'new',
        orderDate: DateTime.now(),
      ));
      return;
    }
    // Atomic, RLS-safe stock decrement + order creation via
    // `place_marketplace_order` (see
    // supabase/migrations/0057_marketplace_order_atomic_placement.sql).
    // This used to be two separate steps — an RPC that verified/decremented
    // stock and handed back a verified price, then a plain client-side
    // `insert into marketplace_orders` using that price — which sounds
    // safe but wasn't: nothing forced a caller to actually use the RPC's
    // result, or to have called the RPC at all. A direct REST call straight
    // to the insert endpoint could set `amount` to anything (a real ₹5,000
    // test product was ordered for ₹1 this way, live-confirmed) while never
    // touching stock — and the old RPC was independently callable on its
    // own with no accompanying order at all, letting any authenticated
    // user silently drain any seller's stock to zero as a pure
    // denial-of-service, no purchase required. `place_marketplace_order`
    // closes both: it performs the stock check-and-decrement AND the order
    // INSERT itself, inside one `security definer` transaction, deriving
    // buyer identity from `auth.uid()`/`profiles.name` rather than trusting
    // any client-supplied value — there is no longer a window between
    // "stock verified" and "order recorded" for a client to skip or forge.
    final rows = await _client.rpc('place_marketplace_order', params: {'p_product_id': productId}) as List;
    final row = rows.first as Map<String, dynamic>;
    final ok = row['success'] as bool;
    if (!ok) throw StateError('This item is out of stock.');
  }

  /// A buyer's own purchase history — was entirely missing (gap-hunt round
  /// 184): `MarketplaceOrdersPage` only ever called `fetchOrdersForSeller`,
  /// so a member who bought something had no way to see it again — the
  /// "Orders" tile every role reaches showed only orders for products she
  /// *sells*, never what she *bought*. `marketplace_orders_select_related`
  /// (RLS) already permits `buyer_id = auth.uid()` reads — this was a pure
  /// missing-UI/repository gap, not an RLS one.
  Future<List<MarketOrder>> fetchOrdersForBuyer(String? buyerId) async {
    // Every `_locallyPlaced` order was created by placeOrder() below — i.e.
    // always a purchase the demo user herself made — so it genuinely
    // belongs on this tab only, no filtering needed.
    if (!_live) return _locallyPlaced.reversed.toList();
    if (buyerId == null) return [];
    final rows = await _client.from('marketplace_orders').select('*, marketplace_products(name, seller_id)').eq('buyer_id', buyerId).order('created_at', ascending: false).limit(200);
    return (rows as List).map((r) => MarketOrder.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Orders for products this seller listed.
  Future<List<MarketOrder>> fetchOrdersForSeller(String? sellerId) async {
    // Was `_locallyPlaced.reversed.toList()` — the exact same list
    // `fetchOrdersForBuyer` returns. Before round 184 gave Orders separate
    // "My Purchases"/"My Sales" tabs, that ambiguity was harmless (there
    // was only one generic Orders screen); presenting the identical list
    // under two now-distinct tab labels made every demo purchase look like
    // a sale too. Demo mode has no other simulated buyer to have ever
    // bought from this user, so there's no real data to show here — an
    // honestly-empty list, not a fabricated one.
    if (!_live) return [];
    if (sellerId == null) return [];
    final rows = await _client
        .from('marketplace_orders')
        .select('*, marketplace_products!inner(name, seller_id)')
        .eq('marketplace_products.seller_id', sellerId)
        .order('created_at', ascending: false)
        .limit(200);
    return (rows as List).map((r) => MarketOrder.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<MarketOrder?> fetchOrderById(String id) async {
    if (!_live) {
      final matches = _locallyPlaced.where((o) => o.id == id);
      return matches.isEmpty ? null : matches.first;
    }
    final row = await _client.from('marketplace_orders').select('*, marketplace_products(name, seller_id)').eq('id', id).maybeSingle();
    return row == null ? null : MarketOrder.fromMap(row);
  }

  Future<void> updateOrderStatus(String id, String status) async {
    if (!_live) {
      final idx = _locallyPlaced.indexWhere((o) => o.id == id);
      if (idx != -1) {
        final o = _locallyPlaced[idx];
        _locallyPlaced[idx] = MarketOrder(id: o.id, productId: o.productId, productName: o.productName, buyerName: o.buyerName, amount: o.amount, status: status, orderDate: o.orderDate);
      }
      return;
    }
    await _client.rpc('advance_marketplace_order_status', params: {'p_order_id': id, 'p_new_status': status});
  }

  /// Reviews across every product this seller lists.
  Future<List<Review>> fetchReviewsForSeller(String? sellerId) async {
    if (!_live) return mock.marketplaceReviews.map((r) => Review(id: r.id, productId: r.productId, reviewerName: r.reviewerName, rating: r.rating, comment: r.comment)).toList();
    if (sellerId == null) return [];
    final rows = await _client
        .from('marketplace_reviews')
        .select('*, marketplace_products!inner(seller_id)')
        .eq('marketplace_products.seller_id', sellerId)
        .order('created_at', ascending: false)
        .limit(300);
    return (rows as List).map((r) => Review.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<List<Review>> fetchReviewsForProduct(String productId) async {
    if (!_live) return mock.marketplaceReviews.where((r) => r.productId == productId).map((r) => Review(id: r.id, productId: r.productId, reviewerName: r.reviewerName, rating: r.rating, comment: r.comment)).toList();
    final rows = await _client.from('marketplace_reviews').select().eq('product_id', productId).order('created_at', ascending: false);
    return (rows as List).map((r) => Review.fromMap(r as Map<String, dynamic>)).toList();
  }

  // `reviewer_id` must be the caller's own id (or omitted) — enforced by
  // `marketplace_reviews_insert_authenticated` (see
  // supabase/migrations/0032_marketplace_reviews_authorship_and_dupes.sql),
  // which also requires the caller to actually have an order for
  // [productId] whenever `reviewer_id` is set, and a partial unique index
  // rejects a second review from the same identified reviewer on the same
  // product. Pass the caller's own profile id here, never anyone else's.
  Future<void> addReview({required String productId, required String? reviewerId, required String reviewerName, required int rating, required String comment}) async {
    if (!_live) return;
    await _client.from('marketplace_reviews').insert({
      'product_id': productId,
      'reviewer_id': ?reviewerId,
      'reviewer_name': reviewerName,
      'rating': rating,
      'comment': comment,
    });
  }

  List<Product> _mockProducts() => (debugProductsOverride ?? mock.marketplaceProducts)
      .map((p) => Product(id: p.id, sellerId: p.id, sellerName: p.sellerName, name: p.name, description: p.description, price: p.price, stock: p.stock, category: p.category))
      .toList();
}
