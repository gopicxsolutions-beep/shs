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

class OrderDetailPage extends StatelessWidget {
  final String orderId;
  const OrderDetailPage({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final repo = MarketplaceRepository();
    final key = GlobalKey<AppAsyncBuilderState<MarketOrder?>>();

    return Scaffold(
      appBar: const PageHeader(title: 'Order Detail'),
      body: AppAsyncBuilder<MarketOrder?>(
        key: key,
        future: () => repo.fetchOrderById(orderId),
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
                  final reachable = SupabaseService.isConfigured;
                  return ChoiceChip(
                    label: Text(e.value),
                    selected: selected,
                    onSelected: !reachable
                        ? null
                        : (_) async {
                            await repo.updateOrderStatus(order.id, e.value);
                            key.currentState?.reload();
                          },
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
