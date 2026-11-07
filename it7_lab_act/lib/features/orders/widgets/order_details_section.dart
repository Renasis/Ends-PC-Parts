import 'package:flutter/material.dart';

import '../models/order.dart';
import 'order_totals.dart';

/// The part of an order card that opens with "View details": delivery
/// information, payment and the price breakdown.
class OrderDetailsSection extends StatelessWidget {
  final Order order;

  const OrderDetailsSection({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final paymentStatus = order.paymentStatusLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        const _Heading('Delivery Information'),
        _InfoRow('Recipient', order.recipientName),
        _InfoRow('Phone', order.phoneNumber),
        _InfoRow('Address', order.deliveryAddress),
        const SizedBox(height: 16),
        const _Heading('Payment'),
        _InfoRow('Method', order.paymentMethod),
        if (paymentStatus.isNotEmpty) _InfoRow('Status', paymentStatus),
        _InfoRow('Order ID', order.id, selectable: true),
        const SizedBox(height: 16),
        const _Heading('Order Summary'),
        OrderTotals(order: order),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;

  const _Heading(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool selectable;

  const _InfoRow(this.label, this.value, {this.selectable = false});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(label, style: TextStyle(color: muted, fontSize: 13)),
          ),
          Expanded(
            child: selectable
                ? SelectableText(value, style: const TextStyle(fontSize: 13))
                : Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
