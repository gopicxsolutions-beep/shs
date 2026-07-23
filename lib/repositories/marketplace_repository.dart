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

  // [amount] is only used in demo mode (no backing table to verify a price
  // against). In live mode the order's real amount is always the price
  // read server-side by `decrement_product_stock` at the moment of
  // purchase — see the comment below — never this caller-supplied value.
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
    // Atomic, RLS-safe stock decrement + server-verified price via
    // `decrement_product_stock` (see
    // supabase/migrations/0008_marketplace_stock_decrement_rpc.sql). This
    // used to be a direct client-side `select stock` → `update stock - 1`
    // followed by inserting the ORDER using whatever `amount` the caller
    // passed in (`product.price`, read earlier into the widget tree — a
    // real trust-boundary gap: a stale page, or a modified client, could
    // record any amount at all for a real order). That had three real
    // bugs: (1) not atomic, so two buyers racing for the last unit could
    // both read stock > 0 and both decrement, overselling; (2)
    // `marketplace_products_write_seller_or_staff` restricts UPDATE to the
    // seller/staff, so a buyer's own update was always silently a 0-row
    // no-op under RLS — stock has never actually decremented for a real
    // purchase; (3) the order amount was never verified server-side. The
    // RPC is `security definer` specifically to cross the RLS boundary
    // safely for exactly one operation (decrement stock by 1 iff > 0), and
    // returns the product's real current price read in the same atomic
    // statement — the order below is inserted using THAT price, not the
    // caller-supplied `amount`, so it can never diverge from what the
    // product actually costs at the moment of purchase.
    num verifiedPrice;
    try {
      final rows = await _client.rpc('decrement_product_stock', params: {'p_product_id': productId}) as List;
      final row = rows.first as Map<String, dynamic>;
      final ok = row['success'] as bool;
      verifiedPrice = row['price'] as num;
      if (!ok) throw StateError('This item is out of stock.');
    } on PostgrestException catch (e) {
      // 'PGRST202' = PostgREST's OWN "function not found in schema cache"
      // code — NOT the underlying Postgres 42883 (undefined_function).
      // First shipped this fix checking for '42883', which is what a raw
      // `psql`/direct-Postgres call would report, but every call made
      // through this Dart client actually goes through PostgREST's REST
      // API, which catches that error and re-wraps it in its own
      // PGRST-prefixed code before it ever reaches `PostgrestException`
      // here — so the '42883' check could NEVER match in this codebase,
      // meaning the fallback below never actually ran and every purchase
      // attempt against an undeployed migration was silently rethrown
      // and failed outright instead of degrading gracefully. Caught live
      // this session: placed a real order against the real (pre-migration)
      // project, watched it silently fail with zero stock/order change,
      // and confirmed the exact code via a direct REST call to the RPC
      // endpoint (`{"code":"PGRST202", "message":"Could not find the
      // function public.decrement_product_stock(p_product_id) in the
      // schema cache"}`) rather than guessing. Once the migration above
      // IS deployed, this fallback still won't fire (the RPC call
      // succeeds), so this is safe to leave in place rather than needing
      // another coordinated removal later — remove it whenever confident
      // every environment running this code has the migration applied.
      // Still re-fetches the price fresh here rather than trusting the
      // caller's `amount` — narrows (doesn't fully close, since this path
      // has no security-definer boundary) the staleness window versus
      // using a value read whenever the product page originally loaded.
      if (e.code != 'PGRST202') rethrow;
      final product = await _client.from('marketplace_products').select('stock, price').eq('id', productId).maybeSingle();
      final stock = product?['stock'] as int?;
      if (stock == null || stock <= 0) throw StateError('This item is out of stock.');
      verifiedPrice = product!['price'] as num;
      await _client.from('marketplace_products').update({'stock': stock - 1}).eq('id', productId);
    }
    await _client.from('marketplace_orders').insert({
      'product_id': productId,
      'buyer_name': buyerName,
      'buyer_id': ?buyerId,
      'amount': verifiedPrice,
      'status': 'new',
    });
  }

  /// Orders for products this seller listed.
  Future<List<MarketOrder>> fetchOrdersForSeller(String? sellerId) async {
    if (!_live) return _locallyPlaced.reversed.toList();
    if (sellerId == null) return [];
    final rows = await _client
        .from('marketplace_orders')
        .select('*, marketplace_products!inner(name, seller_id)')
        .eq('marketplace_products.seller_id', sellerId)
        .order('created_at', ascending: false);
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
    await _client.from('marketplace_orders').update({'status': status}).eq('id', id);
  }

  /// Reviews across every product this seller lists.
  Future<List<Review>> fetchReviewsForSeller(String? sellerId) async {
    if (!_live) return mock.marketplaceReviews.map((r) => Review(id: r.id, productId: r.productId, reviewerName: r.reviewerName, rating: r.rating, comment: r.comment)).toList();
    if (sellerId == null) return [];
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
