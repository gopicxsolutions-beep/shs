import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../l10n/gen/app_localizations.dart';
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

// Same vocabulary as add_product_page.dart's own `_categories` — the actual
// stored values a product's `category` column can hold.
const _categories = ['Handicrafts', 'Tailoring', 'Food', 'Agriculture', 'Other'];

class MarketplaceHomePage extends StatefulWidget {
  const MarketplaceHomePage({super.key});
  @override
  State<MarketplaceHomePage> createState() => _MarketplaceHomePageState();
}

class _MarketplaceHomePageState extends State<MarketplaceHomePage> {
  final _repo = MarketplaceRepository();
  final _search = TextEditingController();
  String? _category;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // Client-side filter over the already-fetched catalog — there was
  // previously no way at all to narrow this cross-SHG product list beyond
  // scrolling everything (the repository's own doc comment admitted this).
  // Case-insensitive substring match on name, same convention as every
  // other search box in this app.
  List<Product> _filtered(List<Product> products) {
    final query = _search.text.trim().toLowerCase();
    return products.where((p) {
      final matchesQuery = query.isEmpty || p.name.toLowerCase().contains(query);
      final matchesCategory = _category == null || p.category == _category;
      return matchesQuery && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: PageHeader(
        title: l10n.marketplaceHomeTitle,
        right: IconButton(icon: const Icon(Icons.add_circle_rounded, color: Brand.c600), onPressed: () => context.go(Paths.marketplaceAddProduct), tooltip: l10n.marketplaceHomeAddProductTooltip),
      ),
      body: AppAsyncBuilder<List<Product>>(
        future: _repo.fetchProducts,
        builder: (context, allProducts) {
          final products = _filtered(allProducts);
          // CustomScrollView/Sliver split so the product grid is genuinely
          // lazy (`SliverGrid.builder`). The previous `GridView.builder`
          // used `shrinkWrap: true` + `NeverScrollableScrollPhysics` to
          // nest inside the page's outer `ListView` — but `shrinkWrap`
          // forces Flutter to lay out *every* item up front to measure the
          // grid's total extent, silently defeating `.builder`'s lazy
          // building. For a marketplace with many sellers/products across
          // every SHG, that meant building every product card (icon
          // container + 3 `Text` widgets each) on every page load,
          // regardless of how many actually fit on screen — the exact
          // "product listings" scale case this app's own domain expects.
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconTile(onTap: () => context.go(Paths.marketplaceAddProduct), icon: Icons.add_business_rounded, label: l10n.marketplaceHomeSellTile, tone: TileTone.brand),
                          IconTile(onTap: () => context.go(Paths.marketplaceOrders), icon: Icons.receipt_long_rounded, label: l10n.marketplaceHomeOrdersTile, tone: TileTone.gold),
                          IconTile(onTap: () => context.go(Paths.marketplaceReviews), icon: Icons.star_rounded, label: l10n.marketplaceHomeReviewsTile, tone: TileTone.sky),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SectionHeader(title: l10n.marketplaceHomeBrowseProducts),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: l10n.marketplaceHomeSearchHint,
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          isDense: true,
                          filled: true,
                          fillColor: Neutral.c50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _CategoryChip(label: l10n.marketplaceHomeCategoryAll, selected: _category == null, onTap: () => setState(() => _category = null)),
                            const SizedBox(width: 8),
                            for (final c in _categories) ...[
                              _CategoryChip(label: marketplaceCategoryLabel(c, l10n), selected: _category == c, onTap: () => setState(() => _category = c)),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (allProducts.isEmpty) AppEmptyState(icon: Icons.storefront_rounded, message: l10n.marketplaceHomeEmptyProducts),
                      if (allProducts.isNotEmpty && products.isEmpty) AppEmptyState(icon: Icons.search_off_rounded, message: l10n.marketplaceHomeNoSearchResults),
                    ],
                  ),
                ),
              ),
              if (products.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverGrid.builder(
                    itemCount: products.length,
                    // childAspectRatio 0.6 (not the visually-squarer 0.8 it
                    // used to be): at a real narrow-phone width (320px) the
                    // 2-column grid's cells are narrow enough that the fixed
                    // 72px icon block + up-to-2-line name + price + seller
                    // name genuinely didn't fit inside a 0.8-ratio cell's
                    // height, overflowing by a few pixels — invisible at
                    // wider widths where the same ratio yields taller cells.
                    // Dropped further from the 0.72 that fixed that (round
                    // 76, 1.0x text scale only) because at a large
                    // accessibility text scale (2.0x) the same 3 lines of
                    // text need noticeably more vertical room than the icon
                    // block can give back even fully collapsed (see the
                    // Expanded below) — this still needs to be a static
                    // ratio (SliverGrid computes every cell's extent up
                    // front from it), so it's sized for the worst case
                    // rather than computed from the live textScaler.
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.6),
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
                              // A fixed 72px-tall icon block leaves a fixed
                              // remainder for the name/price/seller text
                              // below it — comfortable at normal text scale,
                              // but at a large accessibility text scale
                              // those 3 lines need more height than that
                              // remainder has, overflowing the cell (whose
                              // own height is capped by the grid's
                              // childAspectRatio). Expanded lets the icon
                              // block itself shrink to give the growing text
                              // the room it needs instead of overflowing.
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    decoration: BoxDecoration(color: Brand.c50),
                                    alignment: Alignment.center,
                                    width: double.infinity,
                                    child: p.imageUrl == null
                                        ? Icon(Icons.storefront_rounded, color: Brand.c500, size: 28)
                                        : Image.network(
                                            p.imageUrl!,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                            errorBuilder: (context, error, stackTrace) => Icon(Icons.storefront_rounded, color: Brand.c500, size: 28),
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTheme.sans(12, weight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text('₹${NumberFormat('#,##,##0', 'en_IN').format(p.price)}', style: AppTheme.sans(13, weight: FontWeight.w700, color: Brand.c600)),
                              Text(p.sellerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(10, color: Neutral.c500)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: Brand.c50,
      labelStyle: AppTheme.sans(12, weight: FontWeight.w600, color: selected ? Brand.c700 : Neutral.c600),
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? Brand.c500 : Neutral.c200),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}
