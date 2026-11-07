import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/order_status.dart';
import 'order_actions.dart';
import 'order_card_header.dart';
import 'order_details_section.dart';
import 'order_item_tile.dart';
import 'order_timeline.dart';
import 'order_tracking_info.dart';
import 'return_status_section.dart';

/// One order. The summary (id, date, status, first item, tracking, total) is
/// always visible; "View details" opens every item, delivery, payment and
/// the price breakdown.
class OrderCard extends StatefulWidget {
  final Order order;

  /// Shown as a "Cancel order" button when the order can still be cancelled.
  final VoidCallback onCancel;

  /// Shown as an "Order received" button while the order is being shipped.
  final VoidCallback onReceived;

  /// Shown as a "Return" button when the order is completed and can be returned.
  final VoidCallback onReturn;

  /// Shown as a "Reorder" button for completed orders.
  final VoidCallback onReorder;

  const OrderCard({
    super.key,
    required this.order,
    required this.onCancel,
    required this.onReceived,
    required this.onReturn,
    required this.onReorder,
  });

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final scheme = Theme.of(context).colorScheme;
    final shown = _expanded ? order.items : order.items.take(1).toList();
    final hidden = order.items.length - shown.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OrderCardHeader(order: order),
            const Divider(height: 24),
            if (order.items.isEmpty)
              Text(
                'No item details available.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              )
            else
              for (final item in shown) OrderItemTile(item: item),
            if (hidden > 0)
              InkWell(
                onTap: _toggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    '+$hidden more item${hidden == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            OrderTimeline(order: order),
            OrderTrackingInfo(order: order),
            if (_reasonText != null) ...[
              const SizedBox(height: 8),
              Text(
                _reasonText!,
                style: TextStyle(
                  color: order.status == OrderStatus.paymentRejected
                      ? scheme.error
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${order.itemCount} item${order.itemCount == 1 ? '' : 's'}',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                Text(
                  'Order Total: ₱${order.grandTotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: _expanded
                  ? OrderDetailsSection(order: order)
                  : const SizedBox(width: double.infinity),
            ),
            ReturnStatusSection(order: order),
            const SizedBox(height: 8),
            OrderActions(
              order: order,
              expanded: _expanded,
              onToggleDetails: _toggle,
              onCancel: widget.onCancel,
              onReceived: widget.onReceived,
              onReturn: widget.onReturn,
              onReorder: widget.onReorder,
            ),
          ],
        ),
      ),
    );
  }

  /// Why the order was cancelled or its payment refused, when the store or
  /// customer gave a reason.
  String? get _reasonText {
    final order = widget.order;
    if (order.status == OrderStatus.paymentRejected) {
      final reason = order.paymentRejectionText;
      return reason.isEmpty ? null : 'Payment rejected: $reason';
    }
    if (order.status == OrderStatus.cancelled) {
      final who = switch (order.cancelledBy) {
        CancelledBy.customer => 'Cancelled by you',
        CancelledBy.admin => 'Cancelled by the store',
        _ => '',
      };
      final reason = order.cancellationReason;
      if (reason.isEmpty) return who.isEmpty ? null : '$who.';
      return who.isEmpty ? 'Reason: $reason' : '$who. Reason: $reason';
    }
    return null;
  }
}
