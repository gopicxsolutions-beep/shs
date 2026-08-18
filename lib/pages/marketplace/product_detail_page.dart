import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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

class _ProductDetailPageState extends State<ProductDetailPage> {
  final _repo = MarketplaceRepository();
  final _key = GlobalKey<AppAsyncBuilderState<Product?>>();
  final _reviewsKey = GlobalKey<AppAsyncBuilderState<List<Review>>>();
  final _commentController = TextEditingController();
  bool _placing = false;
  bool _submittingReview = false;
  bool _launchingUpi = false;

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

  Future<void> _placeOrder(Product product) async {
    final appState = context.read<AppState>();
    setState(() => _placing = true);
    try {
      await _repo.placeOrder(productId: product.id, buyerName: appState.user.name, buyerId: appState.profile?.id, amount: product.price);
      // Without this, the stock count shown on this already-open page never
      // reflected a successful order (only ever refetched once at mount) —
      // live-verified: placing an order genuinely decremented stock
      // server-side every time, but this page kept showing the original
      // number with no visible change beyond a brief SnackBar, making it
      // easy to believe an order hadn't gone through and place duplicates.
      _key.currentState?.reload();
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(SupabaseService.isConfigured ? l10n.productDetailOrderPlaced : l10n.productDetailOrderDemoMode)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.productDetailOrderPlaceError)));
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  // No real payment-gateway integration exists in this app (no gateway
  // credentials to wire one up) — this opens the buyer's OWN UPI app
  // pre-filled with the seller's UPI ID, mirroring the manual-pay pattern
  // this app already uses for SHG savings payments. The order itself is
  // still placed through the normal `_placeOrder` flow above; there is no
  // payment-reference/order linkage in this pass.
  Future<void> _payViaUpi(Product product) async {
    if (_launchingUpi) return;
    setState(() => _launchingUpi = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      final uri = Uri(
        scheme: 'upi',
        host: 'pay',
        queryParameters: {
          'pa': product.upiId!,
          'pn': product.sellerName,
          'am': product.price.toString(),
          'cu': 'INR',
          if (product.paymentNote != null && product.paymentNote!.isNotEmpty) 'tn': product.paymentNote!,
        },
      );
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
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
              const SizedBox(height: 12),
              Text('₹${NumberFormat('#,##,##0', 'en_IN').format(product.price)}', style: AppTheme.display(22, color: Brand.c700)),
              const SizedBox(height: 4),
              Text(l10n.productDetailInStock(product.stock), style: AppTheme.sans(12, color: product.stock > 0 ? Neutral.c500 : Accent.red600)),
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
                action: isOwnProduct ? null : (_submittingReview ? l10n.productDetailSubmittingAction : l10n.productDetailWriteReviewAction),
                onAction: isOwnProduct ? null : () => _writeReview(productId),
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
                      children: reviews.map((r) => Padding(
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
                                ]),
                                if (r.comment != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(r.comment!, style: AppTheme.sans(12, color: Neutral.c600))),
                              ],
                            ),
                          )).toList(),
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
