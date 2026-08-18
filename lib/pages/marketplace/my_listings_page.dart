import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/marketplace.dart';
import '../../repositories/marketplace_repository.dart';
import '../../routes/paths.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';

/// A seller's own listings, with edit/delist-relist actions —
/// `MarketplaceRepository.fetchMyProducts()` existed with zero UI callers
/// before this page; a seller previously had no way to edit a listing's
/// details or take it down at all.
class MyListingsPage extends StatefulWidget {
  // Injectable for tests, mirrors this module's other repository seams.
  final MarketplaceRepository? repository;
  const MyListingsPage({super.key, this.repository});
  @override
  State<MyListingsPage> createState() => _MyListingsPageState();
}

class _MyListingsPageState extends State<MyListingsPage> {
  late final MarketplaceRepository _repo = widget.repository ?? MarketplaceRepository();
  final _key = GlobalKey<AppAsyncBuilderState<List<Product>>>();
  // Only the row currently being toggled is disabled, not the whole list —
  // mirrors meeting_attendance_page.dart's `_updating` set for the same
  // per-row-busy shape.
  String? _busyId;

  Future<void> _toggleActive(Product product) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(product.isActive ? l10n.myListingsDelistConfirmTitle : l10n.myListingsRelistConfirmTitle),
        content: Text(product.isActive ? l10n.myListingsDelistConfirmMessage(product.name) : l10n.myListingsRelistConfirmMessage(product.name)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.actionCancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(product.isActive ? l10n.myListingsDelistButton : l10n.myListingsRelistButton)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyId = product.id);
    try {
      await _repo.updateProduct(
        id: product.id,
        name: product.name,
        description: product.description ?? '',
        price: product.price,
        stock: product.stock,
        category: product.category ?? '',
        imageUrl: product.imageUrl,
        upiId: product.upiId,
        paymentNote: product.paymentNote,
        isActive: !product.isActive,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(product.isActive ? l10n.myListingsDelistedSuccess : l10n.myListingsRelistedSuccess),
        ));
        _key.currentState?.reload();
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.myListingsToggleError)));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sellerId = context.select<AppState, String?>((s) => s.profile?.id);
    return Scaffold(
      appBar: PageHeader(title: l10n.myListingsTitle),
      body: AppAsyncBuilder<List<Product>>(
        key: _key,
        future: () => _repo.fetchMyProducts(sellerId),
        builder: (context, products) {
          if (products.isEmpty) {
            return AppEmptyState(icon: Icons.storefront_rounded, message: l10n.myListingsEmpty);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            itemBuilder: (context, i) {
              final product = products[i];
              final busy = _busyId == product.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Flexible(child: Text(product.name, style: AppTheme.sans(13, weight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                              if (!product.isActive) ...[
                                const SizedBox(width: 6),
                                AppBadge(text: l10n.myListingsDelistedBadge, tone: BadgeTone.neutral),
                              ],
                            ]),
                            const SizedBox(height: 2),
                            Text(
                              '₹${NumberFormat('#,##,##0', 'en_IN').format(product.price)} · ${l10n.productDetailInStock(product.stock)}',
                              style: AppTheme.sans(11, color: Neutral.c500),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit_outlined, color: busy ? Neutral.c300 : Brand.c600),
                        tooltip: l10n.myListingsEditTooltip(product.name),
                        onPressed: busy ? null : () => context.go(Paths.marketplaceEditProduct(product.id)),
                      ),
                      IconButton(
                        icon: Icon(product.isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: busy ? Neutral.c300 : Brand.c600),
                        tooltip: product.isActive ? l10n.myListingsDelistTooltip(product.name) : l10n.myListingsRelistTooltip(product.name),
                        onPressed: busy ? null : () => _toggleActive(product),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
