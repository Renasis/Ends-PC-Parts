import 'package:flutter/material.dart';

import '../../../core/utils/copy_text.dart';
import '../../../core/utils/date_format.dart';
import '../models/order.dart';
import '../models/order_status.dart';

/// Shipping details the store entered when the order was shipped: carrier,
/// tracking number (tap to copy), shipped date and estimated delivery.
/// Shows nothing until there is something to show.
class OrderTrackingInfo extends StatelessWidget {
  final Order order;

  const OrderTrackingInfo({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final hasTracking = order.trackingNumber.isNotEmpty;
    final shipped = formatDate(order.shippedAt);
    final estimate = formatDate(order.estimatedDelivery);
    final completed = formatDate(order.completedAt);
    if (!hasTracking &&
        order.shippingCarrier.isEmpty &&
        shipped.isEmpty &&
        estimate.isEmpty) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.local_shipping, size: 20, color: Colors.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.shippingCarrier.isEmpty
                      ? 'Shipping'
                      : 'Shipped via ${order.shippingCarrier}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.blue,
                  ),
                ),
                if (hasTracking)
                  Row(
                    children: [
                      Flexible(
                        child: SelectableText(
                          'Tracking no.: ${order.trackingNumber}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy tracking number',
                        onPressed: () => copyText(
                          context,
                          order.trackingNumber,
                          'Tracking number copied',
                        ),
                        icon: const Icon(Icons.copy),
                        iconSize: 16,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        constraints: const BoxConstraints(),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                if (shipped.isNotEmpty) Text('Shipped on $shipped', style: muted),
                if (estimate.isNotEmpty)
                  Text('Estimated delivery: $estimate', style: muted),
                if (completed.isNotEmpty)
                  Text(
                    order.completedBy == CompletedBy.auto
                        ? 'Marked as delivered automatically on $completed'
                        : 'You confirmed receipt on $completed',
                    style: muted,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
