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
import '../../widgets/app_button.dart';
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

  // Missing feature, called out by name in SRS.md's Marketplace section:
  // "there is no buyer-initiated cancellation yet." Narrow by design — only
  // while the order is still 'new', before the seller has acted on it at
  // all (see cancel_marketplace_order's own migration for the reasoning).
  Future<void> _cancel(MarketOrder order) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.orderDetailCancelConfirmTitle),
        content: Text(l10n.orderDetailCancelConfirmMessage),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.actionCancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.orderDetailCancelButton)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _updating = true);
    try {
      await _repo.cancelOrder(order.id);
      if (mounted) {
        _key.currentState?.reload();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(SupabaseService.isConfigured ? l10n.orderDetailCancelledSuccess : l10n.profileUpdateDemoMode),
        ));
      }
    } catch (_) {
      // The likeliest real cause is a race with the seller: she started
      // packing between this page loading and the buyer tapping Cancel —
      // `cancel_marketplace_order` only allows 'new' orders, so that attempt
      // is correctly refused. Reloading shows the now-current (no longer
      // cancellable) status instead of leaving a stale Cancel button up.
      if (mounted) {
        _key.currentState?.reload();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.orderDetailCancelError)));
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
          // Demo mode has no real seller/buyer identity split — every demo
          // order collapses to the one demo persona (see
          // MarketplaceRepository's own class doc comment) and
          // `appState.profile` is always null there, so `order.sellerId ==
          // appState.profile?.id` could never match even for a demo order
          // this same persona "sold." Without this, only a staff-role demo
          // persona could ever see the status chips, making the seller
          // fulfillment flow untestable in demo mode for the leader/member
          // roles it actually exists for.
          final canUpdateStatus = isStaff || !SupabaseService.isConfigured || (order.sellerId != null && order.sellerId == appState.profile?.id);
          // Buyer-only, and only while the order is still 'new' — see
          // cancel_marketplace_order's own migration for why. Not staff:
          // cancellation restores stock atomically in a way
          // advance_marketplace_order_status deliberately can never be used
          // for (migration 0156), so it stays a dedicated buyer action, not
          // folded into staff's broader status-override powers.
          final canCancel = order.status == 'new' && (!SupabaseService.isConfigured || (order.buyerId != null && order.buyerId == appState.profile?.id));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Expanded(child: Text(order.productName, style: AppTheme.sans(15, weight: FontWeight.w700))),
                      AppBadge(text: marketplaceOrderStatusLabel(order.status, l10n), tone: BadgeTone.brand),
                    ]),
                    const SizedBox(height: 6),
                    Text(l10n.orderDetailBuyerLabel(order.buyerName), style: AppTheme.sans(12, color: Neutral.c500)),
                    Text(l10n.orderDetailOrderedOn(DateFormat('dd MMM yyyy').format(order.orderDate)), style: AppTheme.sans(12, color: Neutral.c500)),
                    if (order.quantity > 1) Text(l10n.orderDetailQuantity(order.quantity), style: AppTheme.sans(12, color: Neutral.c500)),
                    const SizedBox(height: 8),
                    Text('₹${NumberFormat('#,##,##0', 'en_IN').format(order.amount)}', style: AppTheme.display(18)),
                  ],
                ),
              ),
              if (canCancel) ...[
                const SizedBox(height: 16),
                AppButton(
                  label: _updating ? l10n.orderDetailCancelling : l10n.orderDetailCancelButton,
                  fullWidth: true,
                  variant: ButtonVariant.outline,
                  onPressed: _updating ? null : () => _cancel(order),
                ),
              ],
              if (canUpdateStatus) ...[
                const SizedBox(height: 20),
                Text(l10n.orderDetailUpdateStatusLabel, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _statusFlow.asMap().entries.map((e) {
                    final selected = e.key == currentIndex;
                    // Non-staff sellers can only move one step forward or
                    // back per call (`advance_marketplace_order_status`,
                    // migration 0068) — disable unreachable chips instead of
                    // letting the tap fail with a server-side exception.
                    final reachable = !_updating && (isStaff || selected || (currentIndex != -1 && (e.key - currentIndex).abs() == 1));
                    return ChoiceChip(
                      label: Text(marketplaceOrderStatusLabel(e.value, l10n)),
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
