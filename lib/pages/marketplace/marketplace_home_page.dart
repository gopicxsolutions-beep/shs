import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../layout/page_header.dart';
import '../../models/marketplace.dart';
import '../../repositories/marketplace_repository.dart';
import '../../routes/paths.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/section_header.dart';

class MarketplaceHomePage extends StatelessWidget {
  const MarketplaceHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = MarketplaceRepository();

    return Scaffold(
      appBar: PageHeader(
        title: 'Marketplace',
        right: IconButton(icon: const Icon(Icons.add_circle_rounded, color: Brand.c600), onPressed: () => context.go(Paths.marketplaceAddProduct)),
      ),
      body: AppAsyncBuilder<List<Product>>(
        future: repo.fetchProducts,
        builder: (context, products) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconTile(onTap: () => context.go(Paths.marketplaceAddProduct), icon: Icons.add_business_rounded, label: 'Sell', tone: TileTone.brand),
                  IconTile(onTap: () => context.go(Paths.marketplaceOrders), icon: Icons.receipt_long_rounded, label: 'Orders', tone: TileTone.gold),
                  IconTile(onTap: () => context.go(Paths.marketplaceReviews), icon: Icons.star_rounded, label: 'Reviews', tone: TileTone.sky),
                ],
              ),
              const SizedBox(height: 20),
              const SectionHeader(title: 'Browse Products'),
              if (products.isEmpty)
                const AppEmptyState(icon: Icons.storefront_rounded, message: 'No products listed yet')
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.8),
                  itemBuilder: (context, i) {
                    final p = products[i];
                    return AppCard(
                      padded: false,
                      onTap: () => context.go(Paths.marketplaceProduct(p.id)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 72,
                              decoration: BoxDecoration(color: Brand.c50, borderRadius: BorderRadius.circular(10)),
                              alignment: Alignment.center,
                              child: Icon(Icons.storefront_rounded, color: Brand.c500, size: 28),
                            ),
                            const SizedBox(height: 8),
                            Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTheme.sans(12, weight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text('₹${NumberFormat('#,##0').format(p.price)}', style: AppTheme.sans(13, weight: FontWeight.w700, color: Brand.c600)),
                            Text(p.sellerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(10, color: Neutral.c500)),
                          ],
                        ),
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
