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
import '../../widgets/list_row.dart';

const _statusTones = <String, BadgeTone>{
  'new': BadgeTone.warning,
  'packed': BadgeTone.info,
  'shipped': BadgeTone.brand,
  'delivered': BadgeTone.success,
};

/// Gap-hunt round 184: this page previously only ever showed orders for
/// products the viewer *sells* (`fetchOrdersForSeller`) — a member who
/// bought something had no way, anywhere in the app, to see that purchase
/// again. Every role reaches this same "Orders" tile from the Marketplace
/// home screen, so a pure buyer (the common case) always saw whatever
/// `fetchOrdersForSeller` returns for a non-seller: an empty list, with no
/// indication that her actual purchase history was simply never queried.
/// Two tabs now cover both directions — "My Purchases" is listed first
/// since buying is the more common action than selling.
class MarketplaceOrdersPage extends StatelessWidget {
  const MarketplaceOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final repo = MarketplaceRepository();
    final myId = appState.profile?.id;
    final l10n = AppLocalizations.of(context)!;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: PageHeader(title: l10n.marketplaceOrdersTitle),
        body: Column(
          children: [
            Material(
              color: Colors.transparent,
              child: TabBar(
                labelColor: Brand.c700,
                unselectedLabelColor: Neutral.c500,
                indicatorColor: Brand.c600,
                tabs: [
                  Tab(text: l10n.marketplaceOrdersMyPurchasesTab),
                  Tab(text: l10n.marketplaceOrdersMySalesTab),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _OrderList(future: () => repo.fetchOrdersForBuyer(myId), emptyMessage: l10n.marketplaceOrdersBuyerEmpty, showBuyerName: false),
                  _OrderList(future: () => repo.fetchOrdersForSeller(myId), emptyMessage: l10n.marketplaceOrdersEmpty, showBuyerName: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  final Future<List<MarketOrder>> Function() future;
  final String emptyMessage;
  // The seller's own tab needs the buyer's name (many different buyers, one
  // seller); the buyer's own tab already knows it's her — showing her own
  // name back to her on every row would be redundant noise.
  final bool showBuyerName;
  const _OrderList({required this.future, required this.emptyMessage, required this.showBuyerName});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppAsyncBuilder<List<MarketOrder>>(
      future: future,
      builder: (context, orders) {
        if (orders.isEmpty) {
          // A scrollable ListView, not AppEmptyState returned bare — the new
          // TabBar above this shrinks the remaining vertical budget just
          // enough to overflow at a short landscape viewport (caught by the
          // stress-test suite); wrapping it the same way several other
          // empty-state pages in this app already do lets it scroll instead
          // of hard-overflowing.
          return ListView(children: [AppEmptyState(icon: Icons.receipt_long_rounded, message: emptyMessage)]);
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, i) {
            final o = orders[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padded: false,
                child: AppListRow(
                  title: o.productName,
                  subtitle: showBuyerName ? '${o.buyerName} · ${DateFormat('dd MMM yyyy').format(o.orderDate)}' : DateFormat('dd MMM yyyy').format(o.orderDate),
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('₹${NumberFormat('#,##,##0', 'en_IN').format(o.amount)}', style: AppTheme.sans(13, weight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      AppBadge(text: marketplaceOrderStatusLabel(o.status, l10n), tone: _statusTones[o.status] ?? BadgeTone.neutral),
                    ],
                  ),
                  onTap: () => context.go(Paths.marketplaceOrderDetail(o.id)),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
