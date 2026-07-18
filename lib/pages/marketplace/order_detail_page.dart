import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../layout/page_header.dart';
import '../../models/marketplace.dart';
import '../../repositories/marketplace_repository.dart';
import '../../services/supabase_service.dart';
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
      if (mounted) _key.currentState?.reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update the order status. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PageHeader(title: 'Order Detail'),
      body: AppAsyncBuilder<MarketOrder?>(
        key: _key,
        future: () => _repo.fetchOrderById(widget.orderId),
        builder: (context, order) {
          if (order == null) {
            return const AppEmptyState(icon: Icons.error_outline_rounded, message: 'This order could not be found');
          }
          final currentIndex = _statusFlow.indexOf(order.status);
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
                    Text('Buyer: ${order.buyerName}', style: AppTheme.sans(12, color: Neutral.c500)),
                    Text('Ordered ${DateFormat('dd MMM yyyy').format(order.orderDate)}', style: AppTheme.sans(12, color: Neutral.c500)),
                    const SizedBox(height: 8),
                    Text('₹${order.amount}', style: AppTheme.display(18)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('Update status', style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _statusFlow.asMap().entries.map((e) {
                  final selected = e.key == currentIndex;
                  final reachable = SupabaseService.isConfigured && !_updating;
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
          );
        },
      ),
    );
  }
}
