import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/error_state.dart';
import '../../cart/providers/cart_provider.dart';
import '../models/order.dart';
import '../models/order_filter.dart';
import '../providers/orders_provider.dart';
import 'cancel_order_dialog.dart';
import 'confirm_return_dialog.dart';
import 'order_card.dart';
import 'orders_empty_state.dart';

/// The signed-in customer's orders for one [OrderFilter], with loading,
/// error and empty states.
class OrdersList extends StatelessWidget {
  final OrderFilter filter;

  const OrdersList({super.key, this.filter = OrderFilter.all});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrdersProvider>();

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.errorMessage.isNotEmpty) {
      return ErrorState(
        message: provider.errorMessage,
        onRetry: provider.retry,
      );
    }

    final orders = provider.ordersFor(filter);
    if (orders.isEmpty) {
      return OrdersEmptyState(
        message: filter == OrderFilter.all
            ? 'No orders placed yet.'
            : 'No ${filter.label} orders found.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return OrderCard(
          order: order,
          onCancel: () => _cancel(context, order),
          onReceived: () => _received(context, order),
          onReturn: () => _return(context, order),
          onReorder: () => _reorder(context, order),
        )
            .animate(delay: ((index < 8 ? index : 8) * 60).ms)
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.05, end: 0);
      },
    );
  }

  Future<void> _cancel(BuildContext context, Order order) async {
    final provider = context.read<OrdersProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final reason = await askCancelReason(context);
    if (reason == null) return;

    final error = await provider.cancelOrder(order, reason);
    messenger.showSnackBar(
      SnackBar(
        content: Text(error ?? 'Order cancelled.'),
        backgroundColor: error == null ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _received(BuildContext context, Order order) async {
    final provider = context.read<OrdersProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Order received?'),
        content: const Text(
          'Only confirm once you have the items in your hands. The order '
          'will be marked Completed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Yes, I got it'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final error = await provider.markReceived(order);
    messenger.showSnackBar(
      SnackBar(
        content: Text(error ?? 'Thank you! Your order is now completed.'),
        backgroundColor: error == null ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _return(BuildContext context, Order order) async {
    final provider = context.read<OrdersProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final result = await confirmReturnOrder(context, order);
    if (result == null) return;

    final error = await provider.requestReturn(
      order,
      result.reason,
      returnImageUrl: result.imageUrl,
      refundMethod: result.refundMethod,
      accountName: result.accountName,
      accountNumber: result.accountNumber,
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(error ?? 'Return request submitted.'),
        backgroundColor: error == null ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _reorder(BuildContext context, Order order) async {
    final ordersProvider = context.read<OrdersProvider>();
    final cartProvider = context.read<CartProvider>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      final cartItems = await ordersProvider.buildReorderItems(order);
      if (cartItems.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('No items found to reorder.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      var added = 0;
      for (final item in cartItems) {
        final error = cartProvider.addItem(
          item.product,
          quantity: item.quantity,
          variantSelection: item.variantSelection,
        );
        if (error == null) added++;
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            added == cartItems.length
                ? '$added item(s) added to cart.'
                : '$added of ${cartItems.length} item(s) added to cart.',
          ),
          backgroundColor: added > 0 ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      debugPrint('OrdersList: reorder failed: $e');
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not reorder items. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}