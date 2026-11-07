import 'package:flutter/material.dart';

import '../../../core/utils/date_format.dart';
import '../models/order.dart';
import '../models/order_status.dart';

/// Four steps showing how far the order has come:
/// placed, processing, shipped, delivered.
///
/// Shown for orders that are still moving forward or finished. Cancelled and
/// payment-rejected orders have no timeline; their reason is shown instead.
class OrderTimeline extends StatelessWidget {
  final Order order;

  const OrderTimeline({super.key, required this.order});

  /// The last step reached (0-3), or null when there is nothing to show.
  static int? stepFor(Order order) {
    switch (order.status) {
      case OrderStatus.pending:
        return 0;
      case OrderStatus.processing:
        return 1;
      case OrderStatus.shipping:
        return 2;
      case OrderStatus.completed:
      case OrderStatus.returned:
        return 3;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final reached = stepFor(order);
    if (reached == null) return const SizedBox.shrink();

    final steps = [
      _Step(
        'Placed',
        Icons.receipt_long,
        formatDate(order.createdAt),
      ),
      _Step(
        'Processing',
        Icons.inventory_2,
        order.isAwaitingPaymentCheck ? 'Checking payment' : '',
      ),
      _Step('Shipped', Icons.local_shipping, formatDate(order.shippedAt)),
      _Step('Delivered', Icons.check_circle, formatDate(order.completedAt)),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            _StepView(step: steps[i], done: i <= reached, current: i == reached),
            if (i < steps.length - 1)
              Expanded(child: _Connector(done: i < reached)),
          ],
        ],
      ),
    );
  }
}

class _Step {
  final String label;
  final IconData icon;
  final String note;

  const _Step(this.label, this.icon, this.note);
}

class _StepView extends StatelessWidget {
  final _Step step;
  final bool done;
  final bool current;

  const _StepView({
    required this.step,
    required this.done,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = done ? scheme.primary : scheme.outlineVariant;

    return SizedBox(
      width: 60,
      child: Column(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? color : Colors.transparent,
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(
              step.icon,
              size: 13,
              color: done ? scheme.onPrimary : scheme.outlineVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            step.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: current ? FontWeight.bold : FontWeight.normal,
              color: done ? scheme.onSurface : scheme.onSurfaceVariant,
            ),
          ),
          if (done && step.note.isNotEmpty)
            Text(
              step.note,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

class _Connector extends StatelessWidget {
  final bool done;

  const _Connector({required this.done});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      // Lines up with the middle of the 24px circles.
      padding: const EdgeInsets.only(top: 11),
      child: Container(
        height: 2,
        color: done ? scheme.primary : scheme.outlineVariant,
      ),
    );
  }
}
