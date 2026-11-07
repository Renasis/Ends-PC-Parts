import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/order_status.dart';

/// The buttons at the bottom of an order card. Only the actions that apply
/// to the order's current state are shown.
class OrderActions extends StatelessWidget {
  final Order order;
  final bool expanded;
  final VoidCallback onToggleDetails;
  final VoidCallback onCancel;
  final VoidCallback onReceived;
  final VoidCallback onReturn;
  final VoidCallback onReorder;

  const OrderActions({
    super.key,
    required this.order,
    required this.expanded,
    required this.onToggleDetails,
    required this.onCancel,
    required this.onReceived,
    required this.onReturn,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        TextButton.icon(
          onPressed: onToggleDetails,
          icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
          label: Text(expanded ? 'Hide details' : 'View details'),
        ),
        if (order.canCancel)
          OutlinedButton.icon(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.error,
              side: BorderSide(color: scheme.error),
            ),
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Cancel order'),
          ),
        if (order.canMarkReceived)
          FilledButton.icon(
            onPressed: onReceived,
            icon: const Icon(Icons.inventory_2_outlined, size: 18),
            label: const Text('Order received'),
          ),
        if (order.canReturn)
          OutlinedButton.icon(
            onPressed: onReturn,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
              side: const BorderSide(color: Colors.orange),
            ),
            icon: const Icon(Icons.assignment_return_outlined, size: 18),
            label: const Text('Request Return'),
          ),
        if (order.status == OrderStatus.completed)
          FilledButton.tonalIcon(
            onPressed: onReorder,
            icon: const Icon(Icons.add_shopping_cart, size: 18),
            label: const Text('Reorder'),
          ),
      ],
    );
  }
}
