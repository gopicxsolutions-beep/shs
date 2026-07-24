import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/marketplace.dart';
import '../../models/types.dart';
import '../../repositories/marketplace_repository.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';

const _statusFlow = ['new', 'packed', 'shipped', 'delivered'];

class OrderDetailPage extends StatefulWidget {
  final String orderId;
  const OrderDetailPage({super.key, required this.orderId});
  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  final _repo = MarketplaceRepository();
  final _key = GlobalKey<AppAsyncBuilderState<MarketOrder?>>();
  bool _updating = false;

  Future<void> _updateStatus(MarketOrder order, String status) async {
    setState(() => _updating = true);
    try {
      await _repo.updateOrderStatus(order.id, status);
      if (mounted) {
        _key.currentState?.reload();
        if (!SupabaseService.isConfigured) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.profileUpdateDemoMode)));
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.orderDetailUpdateStatusError)));
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: PageHeader(title: l10n.orderDetailTitle),
      body: AppAsyncBuilder<MarketOrder?>(
        key: _key,
        future: () => _repo.fetchOrderById(widget.orderId),
        builder: (context, order) {
          if (order == null) {
            return AppEmptyState(icon: Icons.error_outline_rounded, message: l10n.orderDetailNotFound);
          }
          final currentIndex = _statusFlow.indexOf(order.status);
          // `marketplace_orders_update_seller_or_staff` (RLS) only lets the
          // product's seller or staff update an order's status — but this
          // page is also reachable by the BUYER viewing their own order
          // (marketplace_orders_select_related allows buyer_id = auth.uid()).
          // A buyer tapping one of these chips would previously hit a
          // silent RLS no-op (0 rows updated, no exception raised), then
          // reload to find the status unchanged with no explanation.
          final appState = context.watch<AppState>();
          final isStaff = const {Role.crp, Role.clf, Role.admin}.contains(appState.user.role);
          final canUpdateStatus = isStaff || (order.sellerId != null && order.sellerId == appState.profile?.id);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Expanded(child: Text(order.productName, style: AppTheme.sans(15, weight: FontWeight.w700))),
                      AppBadge(text: order.status, tone: BadgeTone.brand),
                    ]),
                    const SizedBox(height: 6),
                    Text(l10n.orderDetailBuyerLabel(order.buyerName), style: AppTheme.sans(12, color: Neutral.c500)),
                    Text(l10n.orderDetailOrderedOn(DateFormat('dd MMM yyyy').format(order.orderDate)), style: AppTheme.sans(12, color: Neutral.c500)),
                    const SizedBox(height: 8),
                    Text('₹${NumberFormat('#,##,##0', 'en_IN').format(order.amount)}', style: AppTheme.display(18)),
                  ],
                ),
              ),
              if (canUpdateStatus) ...[
                const SizedBox(height: 20),
                Text(l10n.orderDetailUpdateStatusLabel, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _statusFlow.asMap().entries.map((e) {
                    final selected = e.key == currentIndex;
                    final reachable = !_updating;
                    return ChoiceChip(
                      label: Text(e.value),
                      selected: selected,
                      onSelected: !reachable ? null : (_) => _updateStatus(order, e.value),
                      selectedColor: Brand.c50,
                      labelStyle: AppTheme.sans(12, weight: FontWeight.w600, color: selected ? Brand.c700 : Neutral.c600),
                      backgroundColor: Colors.white,
                      side: BorderSide(color: selected ? Brand.c500 : Neutral.c200),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    );
                  }).toList(),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
