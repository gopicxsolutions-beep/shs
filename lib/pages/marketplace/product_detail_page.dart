import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/marketplace.dart';
import '../../repositories/marketplace_repository.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/section_header.dart';

class ProductDetailPage extends StatefulWidget {
  final String productId;
  const ProductDetailPage({super.key, required this.productId});
  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

/// Every rejection reason `place_marketplace_order` can raise now maps to its
/// own explanation — before this, ALL of them (out of stock, a deactivated
/// account, a delisted product, a self-order attempt, the 20-orders/hour
/// rate limit) collapsed into one generic "Could not place this order,"
/// giving a buyer no way to tell "try again later" apart from "this will
/// never work" or "pick a smaller quantity." Matched by the exact `RAISE
/// EXCEPTION` message text each check in the function uses — see
/// supabase/migrations/0154_iteration47_marketplace_order_regression_fix.sql
/// for the current source of truth on what those strings are. A top-level
/// function (not a private method on the page's State) so it's testable
/// without pumping a widget.
String marketplaceOrderErrorMessage(Object error, AppLocalizations l10n) {
  if (error is MarketplaceOutOfStockException) return l10n.productDetailOrderErrorOutOfStock;
  final message = error is PostgrestException ? error.message : error.toString();
  if (message.contains('deactivated')) return l10n.productDetailOrderErrorAccountDeactivated;
  if (message.contains('too many orders')) return l10n.productDetailOrderErrorRateLimited;
  if (message.contains('cannot order your own product')) return l10n.productDetailOrderErrorSelfOrder;
  if (message.contains('no longer available')) return l10n.productDetailOrderErrorUnavailable;
  return l10n.productDetailOrderPlaceError;
}

/// Missing feature: the "Pay via UPI" button's deep link required the
/// buyer's phone to already have a UPI app configured to resolve `upi://`
/// — with none, or on a desktop browser, tapping it silently does nothing
/// useful. A QR code of this exact same URI lets any UPI app scan it
/// instead, the same fallback already offered for SHG savings payments
/// (`payments_qr_page.dart`). No real payment-gateway integration exists in
/// this app (no gateway credentials to wire one up) — this only builds a
/// manual-pay deep link, the identical one the button already launches; a
/// top-level function (not inlined in the widget) so both call sites can
/// never drift apart, and so it's directly testable without pumping a
/// widget (`QrImageView`'s own encoded data isn't otherwise inspectable —
/// it's a private field with no public getter).
Uri marketplaceUpiPaymentUri({required String upiId, required String payeeName, required num amount, String? note}) => Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': upiId,
        'pn': payeeName,
        'am': amount.toString(),
        'cu': 'INR',
        if (note != null && note.isNotEmpty) 'tn': note,
      },
    );

class _ProductDetailPageState extends State<ProductDetailPage> {
  final _repo = MarketplaceRepository();
  final _key = GlobalKey<AppAsyncBuilderState<Product?>>();
  final _reviewsKey = GlobalKey<AppAsyncBuilderState<List<Review>>>();
  final _commentController = TextEditingController();
  bool _placing = false;
  bool _submittingReview = false;
  bool _launchingUpi = false;
  // Missing feature: "Write a Review" used to be offered regardless of
  // eligibility — see `MarketplaceRepository.canReviewProduct`'s own doc
  // comment. Demo mode never needed this (its own `isOwnProduct` guard is
  // already `SupabaseService.isConfigured`-gated, so this only ever matters
  // in live mode, where `canReviewProduct` itself is), so this simply stays
  // false — demo mode keeps offering the review action unconditionally,
  // unchanged (its `addReview()` does genuinely persist locally now, but
  // still isn't gated by delivered-order eligibility the way live mode is).
  bool _canReview = false;

  @override
  void initState() {
    super.initState();
    if (SupabaseService.isConfigured) _loadCanReview();
  }

  Future<void> _loadCanReview() async {
    final viewerId = context.read<AppState>().profile?.id;
    final canReview = await _repo.canReviewProduct(widget.productId, viewerId);
    if (mounted) setState(() => _canReview = canReview);
  }
  // User-reported gap: the Buy flow had no quantity concept at all — every
  // order was hard-coded to exactly 1 unit, with no way to ask for more.
  // Clamped against the loaded product's current stock in `build` (never
  // mutated directly there — see `_quantityFor`), so a stock change from
  // reloading after a purchase can't leave this pointing past the new max.
  int _quantity = 1;

  /// The quantity actually usable for [product] right now — [_quantity]
  /// clamped to its current stock (at least 1, so the field never reads 0
  /// while the Place Order button is simply disabled for a sold-out item).
  int _quantityFor(Product product) {
    final maxQty = product.stock <= 0 ? 1 : product.stock;
    if (_quantity < 1) return 1;
    if (_quantity > maxQty) return maxQty;
    return _quantity;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // `MarketplaceRepository.addReview()` was a fully-working, RLS-backed
  // write (see its doc comment — migration 0032 restricts it to a reviewer
  // who actually has an order for this product, one review each) with
  // genuinely zero call sites anywhere in the app: this page's own Reviews
  // section below could only ever read reviews (`fetchReviewsForProduct`),
  // never write one — a real, functioning feature with no way to reach it.
  Future<void> _writeReview(String productId) async {
    if (_submittingReview) return;
    _commentController.clear();
    int rating = 5;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      // See shg_home_page.dart's identical fix for why: an accidental tap
      // just outside the dialog card otherwise silently discards the
      // rating/comment entered so far, indistinguishable from a real save
      // failing.
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.productDetailWriteReviewTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    5,
                    (i) => IconButton(
                      icon: Icon(i < rating ? Icons.star_rounded : Icons.star_border_rounded, color: Gold.c500, size: 28),
                      onPressed: () => setDialogState(() => rating = i + 1),
                      tooltip: l10n.productDetailStarTooltip(i + 1),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _commentController,
                  maxLength: 300,
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(hintText: l10n.productDetailReviewHint),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.actionCancel)),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.actionSubmit)),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final appState = context.read<AppState>();
    setState(() => _submittingReview = true);
    try {
      await _repo.addReview(
        productId: productId,
        reviewerId: appState.profile?.id,
        reviewerName: appState.user.name,
        rating: rating,
        comment: _commentController.text.trim(),
      );
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(SupabaseService.isConfigured ? l10n.productDetailReviewSubmitted : l10n.productDetailReviewDemoMode),
        ));
        _reviewsKey.currentState?.reload();
        // She's used up her one review for this product — the action must
        // not still offer itself (the unique index would reject a second
        // attempt outright).
        if (SupabaseService.isConfigured) setState(() => _canReview = false);
      }
    } catch (_) {
      // RLS rejects this (e.g. no order yet for this product) as a plain
      // failure, not a distinguishable error code — a generic message here
      // matches this repository layer's other write paths.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.productDetailReviewSubmitError)));
      }
    } finally {
      if (mounted) setState(() => _submittingReview = false);
    }
  }

  // Missing feature: a reviewer had no way to delete her own review — see
  // MarketplaceRepository.deleteReview's own doc comment and migration 0157.
  Future<void> _deleteReview(Review review) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.productDetailDeleteReviewConfirmTitle),
        content: Text(l10n.productDetailDeleteReviewConfirmMessage),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.actionCancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.actionDelete)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _repo.deleteReview(review.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.productDetailReviewDeleted)));
        _reviewsKey.currentState?.reload();
        // She can review this product again now that her old review is gone.
        if (SupabaseService.isConfigured) setState(() => _canReview = true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.productDetailReviewDeleteError)));
      }
    }
  }

  // Completes the finding `_deleteReview` above only partly closed — round
  // 10's own scoping note. Mirrors `_writeReview`'s dialog exactly, just
  // pre-filled from the existing review and calling `updateReview` instead
  // of `addReview` on submit.
  Future<void> _editReview(Review review) async {
    if (_submittingReview) return;
    _commentController.text = review.comment ?? '';
    int rating = review.rating;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.productDetailEditReviewTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    5,
                    (i) => IconButton(
                      icon: Icon(i < rating ? Icons.star_rounded : Icons.star_border_rounded, color: Gold.c500, size: 28),
                      onPressed: () => setDialogState(() => rating = i + 1),
                      tooltip: l10n.productDetailStarTooltip(i + 1),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _commentController,
                  maxLength: 300,
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(hintText: l10n.productDetailReviewHint),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.actionCancel)),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.actionSave)),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _submittingReview = true);
    try {
      await _repo.updateReview(reviewId: review.id, rating: rating, comment: _commentController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.productDetailReviewUpdated)));
        _reviewsKey.currentState?.reload();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.productDetailReviewUpdateError)));
      }
    } finally {
      if (mounted) setState(() => _submittingReview = false);
    }
  }

  Future<void> _placeOrder(Product product) async {
    final appState = context.read<AppState>();
    final quantity = _quantityFor(product);
    setState(() => _placing = true);
    try {
      await _repo.placeOrder(productId: product.id, buyerName: appState.user.name, buyerId: appState.profile?.id, amount: product.price * quantity, quantity: quantity);
      // Without this, the stock count shown on this already-open page never
      // reflected a successful order (only ever refetched once at mount) —
      // live-verified: placing an order genuinely decremented stock
      // server-side every time, but this page kept showing the original
      // number with no visible change beyond a brief SnackBar, making it
      // easy to believe an order hadn't gone through and place duplicates.
      _key.currentState?.reload();
      // Back to 1 for whatever she buys next — leaving it at, say, 5 after a
      // successful 5-unit order reads as "still asking for 5 more," not as
      // "5 were just bought."
      if (mounted) setState(() => _quantity = 1);
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(SupabaseService.isConfigured ? l10n.productDetailOrderPlaced : l10n.productDetailOrderDemoMode)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(marketplaceOrderErrorMessage(e, AppLocalizations.of(context)!))));
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  // The picked quantity, not the bare unit price — this is a manual,
  // order-independent payment (see `marketplaceUpiPaymentUri`'s own doc
  // comment), so nothing else here accounts for buying more than 1. Shared
  // by both the "Pay via UPI" button (`_payViaUpi`, launches it directly)
  // and the QR code below (renders the identical URI as a scannable code)
  // so the two can never show different amounts/payees for the same
  // product.
  Uri _upiPaymentUri(Product product) => marketplaceUpiPaymentUri(
        upiId: product.upiId!,
        payeeName: product.sellerName,
        amount: product.price * _quantityFor(product),
        note: product.paymentNote,
      );

  Future<void> _payViaUpi(Product product) async {
    if (_launchingUpi) return;
    setState(() => _launchingUpi = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      final opened = await launchUrl(_upiPaymentUri(product), mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.productDetailUpiLaunchError)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.productDetailUpiLaunchError)));
      }
    } finally {
      if (mounted) setState(() => _launchingUpi = false);
    }
  }

  Widget _quantityStepper(Product product, AppLocalizations l10n) {
    final quantity = _quantityFor(product);
    final total = product.price * quantity;
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.productDetailQuantityLabel, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
                // Only worth a distinct "total" line once it actually
                // differs from the unit price already shown above — at
                // quantity 1 they're the same number, so a second identical
                // line would just be noise.
                if (quantity > 1) ...[
                  const SizedBox(height: 2),
                  Text(l10n.productDetailQuantityTotal('₹${NumberFormat('#,##,##0', 'en_IN').format(total)}'), style: AppTheme.sans(12, color: Neutral.c500)),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline_rounded),
            color: Brand.c600,
            tooltip: l10n.productDetailDecreaseQuantity,
            onPressed: quantity > 1 ? () => setState(() => _quantity = quantity - 1) : null,
          ),
          SizedBox(
            width: 32,
            child: Text('$quantity', textAlign: TextAlign.center, style: AppTheme.display(16)),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            color: Brand.c600,
            tooltip: l10n.productDetailIncreaseQuantity,
            onPressed: quantity < product.stock ? () => setState(() => _quantity = quantity + 1) : null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = _repo;
    final productId = widget.productId;
    final l10n = AppLocalizations.of(context)!;
    // Only `profile?.id` is used below — `.select` avoids rebuilding this
    // page (and re-creating the AppAsyncBuilder futures) on unrelated
    // AppState changes, matching the pattern used throughout this app.
    final viewerId = context.select<AppState, String?>((s) => s.profile?.id);

    return Scaffold(
      appBar: PageHeader(title: l10n.productDetailTitle),
      body: AppAsyncBuilder<Product?>(
        key: _key,
        future: () => repo.fetchProductById(productId),
        builder: (context, product) {
          if (product == null) {
            return AppEmptyState(icon: Icons.error_outline_rounded, message: l10n.productDetailNotFound);
          }
          // `marketplace_reviews_insert_authenticated` (RLS) blocks a
          // seller from reviewing her own product (see
          // MarketplaceRepository.addReview's doc comment) — without this,
          // a seller browsing her own listing saw the same always-offered
          // "Write a Review" action as any buyer, filled out a full
          // rating+comment dialog, and hit a generic "could not submit"
          // error that (accurately, for every OTHER rejection reason) tells
          // buyers to purchase first — nonsensical advice for a seller
          // reviewing her own item, and a dead end no error message could
          // meaningfully explain. `SupabaseService.isConfigured` guards this
          // the same way canRecordPayment/canUpdate-style checks do
          // elsewhere in this app: demo mode has no real seller/buyer
          // identity split (every product's `sellerId` is the same fixed
          // mock id, `appState.profile` is always null), so this check
          // would otherwise hide the action for every demo persona.
          final isOwnProduct = SupabaseService.isConfigured && viewerId != null && product.sellerId == viewerId;
          final canOfferReview = !isOwnProduct && (!SupabaseService.isConfigured || _canReview);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: const BoxDecoration(color: Brand.c50),
                  alignment: Alignment.center,
                  child: product.imageUrl == null
                      ? Icon(Icons.storefront_rounded, color: Brand.c500, size: 56)
                      : Image.network(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stackTrace) => Icon(Icons.storefront_rounded, color: Brand.c500, size: 56),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Text(product.name, style: AppTheme.display(18))),
                Row(children: [
                  if (!product.isActive) ...[
                    AppBadge(text: l10n.productDetailDelistedBadge, tone: BadgeTone.neutral),
                    const SizedBox(width: 6),
                  ],
                  if (product.category != null) AppBadge(text: marketplaceCategoryLabel(product.category!, l10n), tone: BadgeTone.brand),
                ]),
              ]),
              const SizedBox(height: 6),
              Text(l10n.productDetailBySeller(product.sellerName), style: AppTheme.sans(12, color: Neutral.c500)),
              // Missing feature: this header never showed a rating summary
              // at all — the only way to gauge quality was scrolling all
              // the way down to the reviews list.
              if (product.reviewCount > 0) ...[
                const SizedBox(height: 4),
                Semantics(
                  label: l10n.marketplaceHomeProductRatingSemantics(product.avgRating!.toStringAsFixed(1), product.reviewCount),
                  child: ExcludeSemantics(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, size: 14, color: Gold.c500),
                        const SizedBox(width: 3),
                        Text('${product.avgRating!.toStringAsFixed(1)} (${product.reviewCount})', style: AppTheme.sans(12, weight: FontWeight.w600, color: Neutral.c600)),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text('₹${NumberFormat('#,##,##0', 'en_IN').format(product.price)}', style: AppTheme.display(22, color: Brand.c700)),
              const SizedBox(height: 4),
              Text(l10n.productDetailInStock(product.stock), style: AppTheme.sans(12, color: product.stock > 0 ? Neutral.c500 : Accent.red600)),
              if (product.stock > 0 && product.isActive) ...[
                const SizedBox(height: 12),
                // Same visibility condition as the Place Order button below
                // (this app doesn't currently hide that button for a seller
                // viewing her own listing either — not something this fix
                // changes, just staying consistent with it).
                _quantityStepper(product, l10n),
              ],
              const SizedBox(height: 12),
              if (product.description != null) Text(product.description!, style: AppTheme.sans(13, color: Neutral.c700)),
              // Manual UPI payment details — hidden for the seller's own
              // listing (same `isOwnProduct` guard already used below to
              // hide "Write a Review"), whenever no UPI ID was set, and for
              // a delisted product (no point directing a buyer to pay for
              // something she can no longer order).
              if (product.upiId != null && product.upiId!.isNotEmpty && !isOwnProduct && product.isActive) ...[
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.productDetailPaymentDetailsTitle, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
                      const SizedBox(height: 6),
                      Text(l10n.productDetailUpiIdLabel(product.upiId!), style: AppTheme.sans(13)),
                      if (product.paymentNote != null && product.paymentNote!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(product.paymentNote!, style: AppTheme.sans(12, color: Neutral.c600)),
                      ],
                      const SizedBox(height: 12),
                      AppButton(
                        label: _launchingUpi ? l10n.productDetailUpiOpeningInProgress : l10n.productDetailPayViaUpiButton,
                        fullWidth: true,
                        onPressed: _launchingUpi ? null : () => _payViaUpi(product),
                      ),
                      // Missing feature: the UPI ID/"Pay via UPI" button
                      // requires the buyer's phone to actually resolve a
                      // `upi://` deep link into an installed app — on a
                      // device without one configured (or a desktop
                      // browser), that silently does nothing useful. A QR
                      // code of the exact same payment URI lets any UPI
                      // app scan it directly instead, the same fallback
                      // already offered for SHG savings payments
                      // (payments_qr_page.dart). Still no real
                      // gateway/processor — this only renders a scannable
                      // version of data already sent to the button above.
                      const SizedBox(height: 16),
                      Center(
                        child: Column(
                          children: [
                            Text(l10n.productDetailScanToPay, style: AppTheme.sans(11, color: Neutral.c500)),
                            const SizedBox(height: 8),
                            Semantics(
                              label: l10n.productDetailQrCodeSemantics(product.upiId!, NumberFormat('#,##,##0', 'en_IN').format(product.price * _quantityFor(product))),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Neutral.c200)),
                                child: QrImageView(
                                  data: _upiPaymentUri(product).toString(),
                                  version: QrVersions.auto,
                                  size: 160,
                                  gapless: false,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              AppButton(
                label: _placing ? l10n.productDetailPlacingInProgress : l10n.productDetailPlaceOrderButton,
                fullWidth: true,
                size: ButtonSize.lg,
                onPressed: product.stock <= 0 || _placing || !product.isActive ? null : () => _placeOrder(product),
              ),
              const SizedBox(height: 24),
              SectionHeader(
                title: l10n.productDetailReviewsSection,
                // Live mode gates the action on real eligibility
                // (`_canReview` — see its own doc comment): a stranger who
                // never bought this product, a buyer whose order isn't
                // `'delivered'` yet, or someone who's already reviewed it no
                // longer sees "Write a Review" at all, instead of filling
                // out the whole dialog only to hit a flat, unexplained
                // error. Demo mode is unaffected — it has no delivered-
                // order/eligibility concept at all, matching `isOwnProduct`'s
                // identical `SupabaseService.isConfigured` gate just above.
                action: !canOfferReview ? null : (_submittingReview ? l10n.productDetailSubmittingAction : l10n.productDetailWriteReviewAction),
                onAction: !canOfferReview ? null : () => _writeReview(productId),
              ),
              AppAsyncBuilder<List<Review>>(
                key: _reviewsKey,
                future: () => repo.fetchReviewsForProduct(productId),
                builder: (context, reviews) {
                  if (reviews.isEmpty) {
                    return AppEmptyState(icon: Icons.star_border_rounded, message: l10n.productDetailNoReviewsYet);
                  }
                  return AppCard(
                    padded: false,
                    child: Column(
                      children: reviews.map((r) {
                            // Only the review's own author sees a delete
                            // action for it — matches `marketplace_reviews_
                            // delete_own`'s `reviewer_id = auth.uid()` scope
                            // exactly, so this button is never offered for a
                            // review it wouldn't actually be allowed to
                            // delete.
                            final isOwnReview = SupabaseService.isConfigured && viewerId != null && r.reviewerId == viewerId;
                            return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Flexible(child: Text(r.reviewerName, style: AppTheme.sans(12, weight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                                  const SizedBox(width: 8),
                                  Semantics(
                                    label: l10n.productDetailReviewRatingSemantics(r.rating),
                                    child: ExcludeSemantics(
                                      child: Row(children: List.generate(5, (i) => Icon(i < r.rating ? Icons.star_rounded : Icons.star_border_rounded, size: 14, color: Gold.c500))),
                                    ),
                                  ),
                                  if (isOwnReview) ...[
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18),
                                      color: Neutral.c600,
                                      tooltip: l10n.productDetailEditReviewTooltip,
                                      onPressed: () => _editReview(r),
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.only(left: 8),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                      color: Neutral.c600,
                                      tooltip: l10n.productDetailDeleteReviewTooltip,
                                      onPressed: () => _deleteReview(r),
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.only(left: 4),
                                    ),
                                  ],
                                ]),
                                if (r.comment != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(r.comment!, style: AppTheme.sans(12, color: Neutral.c600))),
                              ],
                            ),
                          );
                          }).toList(),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
