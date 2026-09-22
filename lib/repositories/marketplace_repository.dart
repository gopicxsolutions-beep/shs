import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/marketplace.dart' as mock;
import '../models/marketplace.dart';
import '../models/types.dart';
import '../services/supabase_service.dart';

/// Thrown by [MarketplaceRepository.placeOrder] specifically for "not enough
/// stock remains for the quantity requested" — `place_marketplace_order`'s
/// own designed `success: false` path, not a thrown `PostgrestException`
/// (see that method's doc comment for why every OTHER rejection reason is
/// left to propagate as one instead).
class MarketplaceOutOfStockException implements Exception {}

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

  // User bug report: picking any star rating in "Write a Review" and
  // submitting always seemed to leave the review as 5 stars — reproduced
  // directly: the dialog's own star picker was working correctly (confirmed
  // via a widget test tapping each star), but `addReview` was a pure no-op
  // in demo mode (unlike `placeOrder` above, which DOES do a real local
  // write via `_locallyPlaced`) — so whatever was picked never actually
  // landed anywhere, and the review list kept showing only the pre-seeded
  // mock review, which happens to be 5 stars for product 'p1'. Mirrors
  // `_locallyPlaced`'s pattern so a demo-mode review submission is now a
  // genuine (if session-only) write, consistent with every other demo-mode
  // write in this repository.
  static final List<Review> _locallyAddedReviews = [];

  // Test-only seam (null by default, so every existing test keeps seeing
  // the exact short mock.marketplaceProducts it always has).
  // test/routes/long_content_stress_test.dart sets this to exercise a
  // realistic long product name/description at a normal viewport, then
  // resets it — no change to lib/data/marketplace.dart's shared mock
  // records themselves.
  static List<mock.ProductMock>? debugProductsOverride;

  // Test-only seam — `_locallyAddedReviews` is static (deliberately, so a
  // demo-mode review survives page reloads within one session), which means
  // it also survives across tests within the same test file unless cleared.
  // A test that submits a review for a shared product like 'p1' must call
  // this in tearDown, or a later test asserting that product's exact
  // rating/review-count will see this one's leftover state too.
  static void debugClearLocalReviews() => _locallyAddedReviews.clear();

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
    final rows = await _client.from('marketplace_products').select().order('created_at', ascending: false).limit(500);
    return (rows as List).map((r) => Product.fromMap(r as Map<String, dynamic>)).toList();
  }

  // Backs MyListingsPage. The demo branch ignores [sellerId] on purpose,
  // not by omission: demo mode has no real seller/buyer identity split (see
  // this class's own doc comment), so every demo-mode product is already
  // "this persona's own," matching how `placeOrder()`'s demo branch makes
  // the same simplification. Live mode returns a seller's own delisted
  // (`is_active = false`) products too — the RLS `seller_id = auth.uid()`
  // SELECT branch has no `is_active` condition, unlike the general-browse
  // branch — so a seller can always see and manage every listing of hers.
  Future<List<Product>> fetchMyProducts(String? sellerId) async {
    if (!_live) return [..._locallyAddedProducts.reversed, ..._mockProducts()];
    if (sellerId == null) return [];
    final rows = await _client.from('marketplace_products').select().eq('seller_id', sellerId).order('created_at', ascending: false).limit(500);
    return (rows as List).map((r) => Product.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<Product?> fetchProductById(String id) async {
    if (!_live) {
      final matches = [..._locallyAddedProducts, ..._mockProducts()].where((p) => p.id == id);
      return matches.isEmpty ? null : matches.first;
    }
    final row = await _client.from('marketplace_products').select().eq('id', id).maybeSingle();
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
    String? upiId,
    String? paymentNote,
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
        upiId: upiId,
        paymentNote: paymentNote,
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
      'upi_id': ?upiId,
      'payment_note': ?paymentNote,
    });
  }

  /// Edits an existing listing (`AddProductPage`'s edit mode) or toggles its
  /// `isActive` delist/relist flag (`MyListingsPage`) — one method for both,
  /// with [isActive] always required/explicit so neither caller can
  /// accidentally flip it by omission: a field-only edit always echoes back
  /// the listing's current `isActive`, and a delist/relist toggle always
  /// echoes back every other field unchanged. `seller_id`/`created_at` are
  /// locked columns (`marketplace_products_locked_fields`, RLS) — never
  /// sent here, since this never needs to change either.
  /// Returns whether the update actually matched a row — see the RLS note
  /// on the write itself, below, for why this can't just be `Future<void>`.
  Future<bool> updateProduct({
    required String id,
    required String name,
    required String description,
    required num price,
    required int stock,
    // Nullable — matches `marketplace_products.category`'s own nullability
    // and `Product.category`'s type. `my_listings_page.dart`'s delist/relist
    // toggle used to pass `''` for a null category (neither a valid value
    // nor null itself), which `marketplace_products_category_check` (0131,
    // validated in 0137) rejects outright — any listing with a null
    // category could never be delisted or relisted from that page at all.
    String? category,
    String? imageUrl,
    String? upiId,
    String? paymentNote,
    required bool isActive,
  }) async {
    if (!_live) {
      final idx = _locallyAddedProducts.indexWhere((p) => p.id == id);
      if (idx == -1) return false;
      final existing = _locallyAddedProducts[idx];
      _locallyAddedProducts[idx] = Product(
        id: existing.id,
        sellerId: existing.sellerId,
        sellerName: existing.sellerName,
        name: name,
        description: description,
        price: price,
        stock: stock,
        category: category,
        imageUrl: imageUrl,
        upiId: upiId,
        paymentNote: paymentNote,
        isActive: isActive,
      );
      return true;
    }
    // `marketplace_products_update_seller_or_staff`'s USING clause silently
    // matches 0 rows — no exception — for a caller it doesn't authorize
    // (another seller's listing; a listing whose seller was deactivated
    // mid-session; the router has no ownership guard on `/edit-product/:id`,
    // so any product id loads into the edit form for anyone to attempt).
    // Chaining `.select('id')` gets the matched rows back so that case can
    // be told apart from a real success — without this, both AddProductPage
    // and MyListingsPage reported "updated"/"delisted" on a write that
    // silently changed nothing.
    // `image_url`/`upi_id`/`payment_note` used to be `?field` (the
    // null-aware spread that OMITS the key entirely whenever the value is
    // null) — the same "leave unchanged if absent" semantics `addProduct`'s
    // INSERT correctly wants, but wrong here: every caller of `updateProduct`
    // already resolves a definite, final value before calling (the existing
    // one, a freshly-uploaded replacement, or a deliberate null to CLEAR
    // it — `add_product_page.dart`'s `upiIdValue`/`imageUrl` locals, echoed
    // straight back by `my_listings_page.dart`'s delist/relist toggle), so
    // there is no "absent, leave alone" case to preserve. A seller clearing
    // her UPI ID or removing a photo and saving used to have that change
    // silently discarded — the OLD value stayed in the database untouched,
    // and reopening Edit would show it right back as if nothing had
    // happened. Sent unconditionally now, matching `category`'s own
    // already-correct convention.
    final rows = await _client.from('marketplace_products').update({
      'name': name,
      'description': description,
      'price': price,
      'stock': stock,
      'category': category,
      'image_url': imageUrl,
      'upi_id': upiId,
      'payment_note': paymentNote,
      'is_active': isActive,
    }).eq('id', id).select('id');
    return (rows as List).isNotEmpty;
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
  // [amount] is the TOTAL for [quantity] units (i.e. already `unit price x
  // quantity`) — the caller (product_detail_page.dart) computes that, since
  // demo mode has no server round trip to derive it from. Live mode ignores
  // [amount] entirely (as it already did before quantity existed — see the
  // security note below) and re-derives the true total server-side from
  // [quantity] and the product's real current price.
  Future<void> placeOrder({required String productId, required String buyerName, required String? buyerId, required num amount, int quantity = 1}) async {
    if (!_live) {
      final matches = _mockProducts().where((p) => p.id == productId);
      _locallyPlaced.add(MarketOrder(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        productId: productId,
        productName: matches.isEmpty ? productId : matches.first.name,
        sellerId: matches.isEmpty ? null : matches.first.sellerId,
        sellerName: matches.isEmpty ? null : matches.first.sellerName,
        buyerId: buyerId,
        buyerName: buyerName,
        amount: amount,
        quantity: quantity,
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
    // Every OTHER rejection (deactivated buyer/seller, delisted product,
    // self-order, the 20/hour rate limit — migrations 0091/0098/0111/0131,
    // restored after a same-day regression in 0154) reaches the caller as a
    // thrown `PostgrestException` with a specific `.message`, left to
    // propagate here rather than swallowed — `product_detail_page.dart`'s
    // `_placeOrder` maps each one to its own localized explanation instead
    // of the single generic message every one of these used to collapse
    // into. This one case — `success: false`, no exception — is the RPC's
    // own designed non-exceptional path for "not enough stock remains,"
    // distinguished from the others with a dedicated exception type so the
    // UI can tell it apart without string-matching a message.
    final rows = await _client.rpc('place_marketplace_order', params: {'p_product_id': productId, 'p_quantity': quantity}) as List;
    final row = rows.first as Map<String, dynamic>;
    final ok = row['success'] as bool;
    if (!ok) throw MarketplaceOutOfStockException();
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
    final rows = await _client.from('marketplace_orders').select('*, marketplace_products(name, seller_id, seller_name)').eq('buyer_id', buyerId).order('created_at', ascending: false).limit(200);
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
        .select('*, marketplace_products!inner(name, seller_id, seller_name)')
        .eq('marketplace_products.seller_id', sellerId)
        .order('created_at', ascending: false)
        .limit(200);
    return (rows as List).map((r) => MarketOrder.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Missing feature: a seller had no way to know a new order arrived at
  /// all — nothing on the dashboard, no badge, no notification of any kind;
  /// the only way to find out was to open Marketplace > Orders > "My Sales"
  /// and read the list. Backs a badge on the Orders tile
  /// (`marketplace_home_page.dart`), same visual/accessibility pattern
  /// `IconTile`'s own `badge` parameter already supports (built, but with
  /// zero callers anywhere in the app before this). A row-count, not
  /// `.count()`'s cheaper HEAD-request form — that variant can't filter on
  /// an embedded table's column (`marketplace_products.seller_id` here),
  /// only a plain column on `marketplace_orders` itself — but a seller's own
  /// unfulfilled order count is inherently small, unlike the catalog-wide
  /// scale concerns elsewhere in this repository.
  Future<int> fetchPendingSalesCount(String? sellerId) async {
    if (!_live || sellerId == null) return 0;
    final rows = await _client
        .from('marketplace_orders')
        .select('id, marketplace_products!inner(seller_id)')
        .eq('marketplace_products.seller_id', sellerId)
        .eq('status', 'new');
    return (rows as List).length;
  }

  Future<MarketOrder?> fetchOrderById(String id) async {
    if (!_live) {
      final matches = _locallyPlaced.where((o) => o.id == id);
      return matches.isEmpty ? null : matches.first;
    }
    final row = await _client.from('marketplace_orders').select('*, marketplace_products(name, seller_id, seller_name)').eq('id', id).maybeSingle();
    return row == null ? null : MarketOrder.fromMap(row);
  }

  Future<void> updateOrderStatus(String id, String status) async {
    if (!_live) {
      final idx = _locallyPlaced.indexWhere((o) => o.id == id);
      if (idx != -1) {
        final o = _locallyPlaced[idx];
        _locallyPlaced[idx] = MarketOrder(id: o.id, productId: o.productId, productName: o.productName, sellerId: o.sellerId, sellerName: o.sellerName, buyerId: o.buyerId, buyerName: o.buyerName, amount: o.amount, quantity: o.quantity, status: status, orderDate: o.orderDate);
      }
      return;
    }
    await _client.rpc('advance_marketplace_order_status', params: {'p_order_id': id, 'p_new_status': status});
  }

  /// Buyer-initiated cancellation (`cancel_marketplace_order`, migration
  /// 0155) — only while the order is still `'new'` (before the seller has
  /// acted on it at all). Restores the product's stock atomically in the
  /// same `security definer` transaction; demo mode has no stock to restore
  /// (`placeOrder`'s own demo branch never decrements any — see its doc
  /// comment), so this just flips the local order's status.
  Future<void> cancelOrder(String id) async {
    if (!_live) {
      final idx = _locallyPlaced.indexWhere((o) => o.id == id);
      if (idx != -1) {
        final o = _locallyPlaced[idx];
        _locallyPlaced[idx] = MarketOrder(id: o.id, productId: o.productId, productName: o.productName, sellerId: o.sellerId, sellerName: o.sellerName, buyerId: o.buyerId, buyerName: o.buyerName, amount: o.amount, quantity: o.quantity, status: 'cancelled', orderDate: o.orderDate);
      }
      return;
    }
    await _client.rpc('cancel_marketplace_order', params: {'p_order_id': id});
  }

  /// Reviews across every product this seller lists.
  Future<List<Review>> fetchReviewsForSeller(String? sellerId) async {
    // Missing feature: a seller with more than one listing had no way to
    // tell which product a review was even about — the embed below existed
    // only to FILTER (`seller_id`), `name` was never selected even though
    // MarketplaceReviewsPage needed exactly that.
    if (!_live) {
      final seeded = mock.marketplaceReviews.map((r) {
        final matches = mock.marketplaceProducts.where((p) => p.id == r.productId);
        return Review(id: r.id, productId: r.productId, productName: matches.isEmpty ? null : matches.first.name, reviewerName: r.reviewerName, rating: r.rating, comment: r.comment);
      });
      final local = _locallyAddedReviews.map((r) {
        final matches = mock.marketplaceProducts.where((p) => p.id == r.productId);
        return Review(id: r.id, productId: r.productId, productName: matches.isEmpty ? null : matches.first.name, reviewerName: r.reviewerName, rating: r.rating, comment: r.comment);
      });
      return [...local.toList().reversed, ...seeded];
    }
    if (sellerId == null) return [];
    final rows = await _client
        .from('marketplace_reviews')
        .select('*, marketplace_products!inner(seller_id, name)')
        .eq('marketplace_products.seller_id', sellerId)
        .order('created_at', ascending: false)
        .limit(300);
    return (rows as List).map((r) => Review.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<List<Review>> fetchReviewsForProduct(String productId) async {
    if (!_live) {
      final local = _locallyAddedReviews.where((r) => r.productId == productId).toList().reversed;
      final seeded = mock.marketplaceReviews.where((r) => r.productId == productId).map((r) => Review(id: r.id, productId: r.productId, reviewerName: r.reviewerName, rating: r.rating, comment: r.comment));
      return [...local, ...seeded];
    }
    // Matches this file's other bounded list queries (fetchOrdersForBuyer/
    // fetchOrdersForSeller at 200, fetchReviewsForSeller at 300) — was the
    // one remaining unbounded query here, a genuinely popular product could
    // otherwise accumulate an unbounded review list.
    final rows = await _client.from('marketplace_reviews').select().eq('product_id', productId).order('created_at', ascending: false).limit(300);
    return (rows as List).map((r) => Review.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Whether [viewerId] is currently allowed to review [productId] —
  /// mirrors `marketplace_reviews_insert_authenticated` (RLS) exactly: a
  /// `'delivered'` order for this product by her, AND no existing review
  /// from her already (`marketplace_reviews_product_reviewer_uniq`, one per
  /// reviewer per product — a second attempt is rejected outright, not
  /// merged/replaced). Missing feature: "Write a Review" was offered
  /// regardless of either condition — a stranger who never bought it, a
  /// buyer whose order was still `'new'`/`'packed'`/`'shipped'`, or someone
  /// who'd already reviewed it, could all fill out the whole rating+comment
  /// dialog only to hit a flat, unexplained "could not submit" error,
  /// correctly but unhelpfully enforced server-side.
  Future<bool> canReviewProduct(String productId, String? viewerId) async {
    if (!_live || viewerId == null) return false;
    final results = await Future.wait([
      _client.from('marketplace_orders').select('id').eq('product_id', productId).eq('buyer_id', viewerId).eq('status', 'delivered').limit(1),
      _client.from('marketplace_reviews').select('id').eq('product_id', productId).eq('reviewer_id', viewerId).limit(1),
    ]);
    final hasDeliveredOrder = (results[0] as List).isNotEmpty;
    final alreadyReviewed = (results[1] as List).isNotEmpty;
    return hasDeliveredOrder && !alreadyReviewed;
  }

  // `reviewer_id` must be the caller's own id (or omitted) — enforced by
  // `marketplace_reviews_insert_authenticated` (see
  // supabase/migrations/0032_marketplace_reviews_authorship_and_dupes.sql),
  // which also requires the caller to actually have an order for
  // [productId] whenever `reviewer_id` is set, and a partial unique index
  // rejects a second review from the same identified reviewer on the same
  // product. Pass the caller's own profile id here, never anyone else's.
  Future<void> addReview({required String productId, required String? reviewerId, required String reviewerName, required int rating, required String comment}) async {
    if (!_live) {
      _locallyAddedReviews.add(Review(
        id: 'local-review-${DateTime.now().microsecondsSinceEpoch}',
        productId: productId,
        reviewerId: reviewerId,
        reviewerName: reviewerName,
        rating: rating,
        comment: comment.isEmpty ? null : comment,
      ));
      return;
    }
    await _client.from('marketplace_reviews').insert({
      'product_id': productId,
      'reviewer_id': ?reviewerId,
      'reviewer_name': reviewerName,
      'rating': rating,
      'comment': comment,
    });
  }

  // Missing feature: a reviewer had no way to delete her own review at all —
  // only staff could remove someone else's (see
  // supabase/migrations/0157_iteration49_marketplace_review_self_delete.sql).
  // `marketplace_reviews_delete_own` scopes this to `reviewer_id = auth.uid()`
  // — passing any other review's id here is simply a no-op (0 rows match).
  Future<void> deleteReview(String reviewId) async {
    if (!_live) return;
    await _client.from('marketplace_reviews').delete().eq('id', reviewId);
  }

  // Completes the finding `deleteReview` above only partly closed (see its
  // own doc comment): a reviewer had no way to fix a typo or correct a
  // rating without deleting and losing her place entirely (the unique
  // index would then also block a fresh review until the DELETE landed).
  // `marketplace_reviews_update_own` (migration 0159) locks product_id/
  // reviewer_id/reviewer_name/created_at — only rating/comment are settable
  // here, matching what this call sends.
  Future<void> updateReview({required String reviewId, required int rating, required String comment}) async {
    if (!_live) return;
    await _client.from('marketplace_reviews').update({'rating': rating, 'comment': comment}).eq('id', reviewId);
  }

  List<Product> _mockProducts() => (debugProductsOverride ?? mock.marketplaceProducts).map((p) {
        // Includes locally-added demo reviews (see addReview's own doc
        // comment) so a just-submitted rating actually moves the average
        // shown, not just the seeded mock data.
        final ratings = [
          ...mock.marketplaceReviews.where((r) => r.productId == p.id).map((r) => r.rating),
          ..._locallyAddedReviews.where((r) => r.productId == p.id).map((r) => r.rating),
        ];
        final reviewCount = ratings.length;
        return Product(
          id: p.id,
          sellerId: p.id,
          sellerName: p.sellerName,
          name: p.name,
          description: p.description,
          price: p.price,
          stock: p.stock,
          category: p.category,
          upiId: p.upiId,
          paymentNote: p.paymentNote,
          isActive: p.isActive,
          avgRating: reviewCount == 0 ? null : ratings.reduce((a, b) => a + b) / reviewCount,
          reviewCount: reviewCount,
        );
      }).toList();
}
