import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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
  bool _placing = false;

  Future<void> _placeOrder(Product product) async {
    final appState = context.read<AppState>();
    setState(() => _placing = true);
    try {
      await _repo.placeOrder(productId: product.id, buyerName: appState.user.name, buyerId: appState.profile?.id, amount: product.price);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(SupabaseService.isConfigured ? 'Order placed' : 'Demo mode — order not saved (connect Supabase to persist)')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not place this order. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = _repo;
    final productId = widget.productId;

    return Scaffold(
      appBar: const PageHeader(title: 'Product'),
      body: AppAsyncBuilder<Product?>(
        future: () => repo.fetchProductById(productId),
        builder: (context, product) {
          if (product == null) {
            return const AppEmptyState(icon: Icons.error_outline_rounded, message: 'This product could not be found');
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                height: 160,
                decoration: BoxDecoration(color: Brand.c50, borderRadius: BorderRadius.circular(16)),
                alignment: Alignment.center,
                child: Icon(Icons.storefront_rounded, color: Brand.c500, size: 56),
              ),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Text(product.name, style: AppTheme.display(18))),
                if (product.category != null) AppBadge(text: product.category!, tone: BadgeTone.brand),
              ]),
              const SizedBox(height: 6),
              Text('by ${product.sellerName}', style: AppTheme.sans(12, color: Neutral.c500)),
              const SizedBox(height: 12),
              Text('₹${NumberFormat('#,##0').format(product.price)}', style: AppTheme.display(22, color: Brand.c700)),
              const SizedBox(height: 4),
              Text('${product.stock} in stock', style: AppTheme.sans(12, color: product.stock > 0 ? Neutral.c500 : Accent.red600)),
              const SizedBox(height: 12),
              if (product.description != null) Text(product.description!, style: AppTheme.sans(13, color: Neutral.c700)),
              const SizedBox(height: 20),
              AppButton(
                label: _placing ? 'Placing…' : 'Place Order',
                fullWidth: true,
                size: ButtonSize.lg,
                onPressed: product.stock <= 0 || _placing ? null : () => _placeOrder(product),
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Reviews'),
              AppAsyncBuilder<List<Review>>(
                future: () => repo.fetchReviewsForProduct(productId),
                builder: (context, reviews) {
                  if (reviews.isEmpty) {
                    return const AppEmptyState(icon: Icons.star_border_rounded, message: 'No reviews yet');
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
                                  Text(r.reviewerName, style: AppTheme.sans(12, weight: FontWeight.w700)),
                                  const SizedBox(width: 8),
                                  Semantics(
                                    label: '${r.rating} out of 5 stars',
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
