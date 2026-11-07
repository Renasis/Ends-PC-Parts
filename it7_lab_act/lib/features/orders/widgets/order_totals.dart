import 'package:flutter/material.dart';

import '../models/order.dart';

/// Subtotal, discount (when there is one), shipping fee and grand total.
class OrderTotals extends StatelessWidget {
  final Order order;

  const OrderTotals({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        _row('Subtotal', order.subtotal),
        if (order.discount > 0) _row('Discount', -order.discount),
        _row('Shipping Fee', order.shippingFee),
        const SizedBox(height: 6),
        _row(
          'Grand Total',
          order.grandTotal,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: primary,
          ),
        ),
      ],
    );
  }

  Widget _row(String label, double amount, {TextStyle? style}) {
    final sign = amount < 0 ? '-' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('$sign₱${amount.abs().toStringAsFixed(2)}', style: style),
        ],
      ),
    );
  }
}