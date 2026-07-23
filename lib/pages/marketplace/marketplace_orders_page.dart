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

class MarketplaceOrdersPage extends StatelessWidget {
  const MarketplaceOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final repo = MarketplaceRepository();
    final sellerId = appState.profile?.id;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: PageHeader(title: l10n.marketplaceOrdersTitle),
      body: AppAsyncBuilder<List<MarketOrder>>(
        future: () => repo.fetchOrdersForSeller(sellerId),
        builder: (context, orders) {
          if (orders.isEmpty) {
            return AppEmptyState(icon: Icons.receipt_long_rounded, message: l10n.marketplaceOrdersEmpty);
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
                    subtitle: '${o.buyerName} · ${DateFormat('dd MMM yyyy').format(o.orderDate)}',
                    trailing: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('₹${NumberFormat('#,##,##0', 'en_IN').format(o.amount)}', style: AppTheme.sans(13, weight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        AppBadge(text: o.status, tone: _statusTones[o.status] ?? BadgeTone.neutral),
                      ],
                    ),
                    onTap: () => context.go(Paths.marketplaceOrderDetail(o.id)),
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
