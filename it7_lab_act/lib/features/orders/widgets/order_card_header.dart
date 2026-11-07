import 'package:flutter/material.dart';

import '../../../core/utils/copy_text.dart';
import '../../../core/utils/date_format.dart';
import '../models/order.dart';
import 'order_status_style.dart';

/// Top of an order card: order number (tap the icon to copy the full id),
/// the date it was placed and the status badge.
class OrderCardHeader extends StatelessWidget {
  final Order order;

  const OrderCardHeader({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = OrderStatusStyle.of(order.status);
    final placed = formatDateTime(order.createdAt);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Order #${order.shortId}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy order ID',
                    onPressed: () =>
                        copyText(context, order.id, 'Order ID copied'),
                    icon: const Icon(Icons.copy),
                    iconSize: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
              if (placed.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Placed $placed',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: style.color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(style.icon, size: 14, color: style.color),
              const SizedBox(width: 4),
              Text(
                order.status,
                style: TextStyle(
                  color: style.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
