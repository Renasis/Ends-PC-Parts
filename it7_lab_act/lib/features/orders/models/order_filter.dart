import 'order.dart';
import 'order_status.dart';

/// The groups shown on the Account screen ("To Pay", "To Ship", ...).
enum OrderFilter {
  all('All'),
  toPay('To Pay'),
  toShip('To Ship'),
  toReceive('To Receive'),
  completed('Completed'),
  returned('Returned');

  final String label;
  const OrderFilter(this.label);

  bool matches(Order order) {
    switch (this) {
      case OrderFilter.all:
        return true;
      case OrderFilter.toPay:
        return order.status == OrderStatus.paymentRejected ||
            (order.status == OrderStatus.pending &&
                order.isAwaitingPaymentCheck);
      case OrderFilter.toShip:
        return order.status == OrderStatus.processing ||
            (order.status == OrderStatus.pending &&
                !order.isAwaitingPaymentCheck);
      case OrderFilter.toReceive:
        return order.status == OrderStatus.shipping;
      case OrderFilter.completed:
        return order.status == OrderStatus.completed;
      case OrderFilter.returned:
        // Includes return requests still under review or declined, which
        // stay Completed until the admin approves them.
        return order.status == OrderStatus.returned || order.returnedAt > 0;
    }
  }
}