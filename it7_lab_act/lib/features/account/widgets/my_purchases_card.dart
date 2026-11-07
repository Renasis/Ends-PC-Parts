import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/surface_card.dart';
import '../../orders/models/order_filter.dart';
import '../../orders/providers/orders_provider.dart';
import '../../orders/screens/order_history_screen.dart';

/// "To Pay / To Ship / To Receive / Completed" shortcuts with order counts.
class MyPurchasesCard extends StatelessWidget {
  const MyPurchasesCard({super.key});

  static const _entries = [
    (OrderFilter.toPay, Icons.payment_outlined),
    (OrderFilter.toShip, Icons.inventory_2_outlined),
    (OrderFilter.toReceive, Icons.local_shipping_outlined),
    (OrderFilter.completed, Icons.task_alt),
    (OrderFilter.returned, Icons.assignment_return),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orders = context.watch<OrdersProvider>();

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Purchases',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OrderHistoryScreen(),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Row(
                    children: [
                      Text('View history', style: TextStyle(fontSize: 12)),
                      Icon(Icons.chevron_right, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 12),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final (filter, icon) in _entries)
                _PurchaseButton(
                  filter: filter,
                  icon: icon,
                  count: orders.countFor(filter),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PurchaseButton extends StatelessWidget {
  final OrderFilter filter;
  final IconData icon;
  final int count;

  const _PurchaseButton({
    required this.filter,
    required this.icon,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OrderHistoryScreen(filter: filter)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          children: [
            Badge(
              isLabelVisible: count > 0,
              label: Text('$count'),
              child: Icon(icon, size: 28, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 6),
            Text(
              filter.label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
