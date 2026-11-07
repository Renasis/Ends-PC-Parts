import 'package:flutter/material.dart';

import '../models/order_status.dart';

/// Colour and icon used for an order status badge.
class OrderStatusStyle {
  final Color color;
  final IconData icon;

  const OrderStatusStyle(this.color, this.icon);

  static OrderStatusStyle of(String status) {
    switch (status) {
      case OrderStatus.completed:
        return const OrderStatusStyle(Colors.green, Icons.check_circle);
      case OrderStatus.cancelled:
      case OrderStatus.paymentRejected:
        return const OrderStatusStyle(Colors.red, Icons.cancel);
      case OrderStatus.shipping:
        return const OrderStatusStyle(Colors.blue, Icons.local_shipping);
      case OrderStatus.returned:
        return const OrderStatusStyle(Colors.amber, Icons.assignment_return);
      default:
        return OrderStatusStyle(
            Colors.orange.shade800, Icons.pending_actions);
    }
  }
}