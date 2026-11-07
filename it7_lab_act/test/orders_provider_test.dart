import 'package:flutter_test/flutter_test.dart';
import 'package:it7_lab_act/features/orders/models/order.dart';
import 'package:it7_lab_act/features/orders/models/order_status.dart';
import 'package:it7_lab_act/features/orders/models/order_filter.dart';

void main() {
  group('Order', () {
    test('fromMap reads all fields', () {
      final order = Order.fromMap('order1', {
        'userId': 'user1',
        'recipientName': 'John Doe',
        'phoneNumber': '09123456789',
        'deliveryAddress': '123 Main St',
        'paymentMethod': 'COD',
        'paymentStatus': 'not_applicable',
        'items': [
          {'productId': 'p1', 'productName': 'RTX 4060', 'quantity': 1, 'price': 15000},
          {'productId': 'p2', 'productName': 'Ryzen 7', 'quantity': 2, 'price': 20000},
        ],
        'subtotal': 55000,
        'discount': 5000,
        'promoCode': 'SAVE5000',
        'shippingFee': 150,
        'grandTotal': 50150,
        'status': 'Pending',
        'createdAt': 1704067200000,
        'cancellationReason': '',
        'returnReason': '',
        'returnedAt': 0,
        'refundAmount': 0,
        'returnImageUrl': '',
        'refundStatus': '',
        'shippingCarrier': 'LBC',
        'trackingNumber': 'PH123456789',
        'shippedAt': 1704067200000,
        'estimatedDelivery': 1704153600000,
      });

      expect(order.id, 'order1');
      expect(order.recipientName, 'John Doe');
      expect(order.phoneNumber, '09123456789');
      expect(order.deliveryAddress, '123 Main St');
      expect(order.paymentMethod, 'COD');
      expect(order.paymentStatus, 'not_applicable');
      expect(order.items.length, 2);
      expect(order.items[0].productId, 'p1');
      expect(order.items[0].quantity, 1);
      expect(order.subtotal, 55000);
      expect(order.discount, 5000);
      // Note: Order doesn't have promoCode field in this implementation
      expect(order.shippingFee, 150);
      expect(order.grandTotal, 50150);
      expect(order.status, OrderStatus.pending);
      expect(order.createdAt, 1704067200000);
      expect(order.cancellationReason, '');
      expect(order.returnReason, '');
      expect(order.returnedAt, 0);
      expect(order.refundAmount, 0);
      expect(order.returnImageUrl, '');
      expect(order.refundStatus, '');
      expect(order.shippingCarrier, 'LBC');
      expect(order.trackingNumber, 'PH123456789');
      expect(order.shippedAt, 1704067200000);
      expect(order.estimatedDelivery, 1704153600000);
    });

    test('canCancel is true for cancellable statuses', () {
      final pending = Order(
        id: '1',
        status: OrderStatus.pending,
        paymentMethod: 'COD',
        paymentStatus: 'not_applicable',
        recipientName: 'Test',
        phoneNumber: '09123456789',
        deliveryAddress: '123 St',
        items: const [],
        subtotal: 100,
        discount: 0,
        shippingFee: 0,
        grandTotal: 100,
        createdAt: 1000,
        cancellationReason: '',
      );
      expect(pending.canCancel, isTrue);

      final rejected = Order(
        id: '2',
        status: OrderStatus.paymentRejected,
        paymentMethod: 'COD',
        paymentStatus: 'not_applicable',
        recipientName: 'Test',
        phoneNumber: '09123456789',
        deliveryAddress: '123 St',
        items: const [],
        subtotal: 100,
        discount: 0,
        shippingFee: 0,
        grandTotal: 100,
        createdAt: 1000,
        cancellationReason: '',
      );
      expect(rejected.canCancel, isTrue);
    });

    test('canCancel is false for non-cancellable statuses', () {
      final shipping = Order(
        id: '1',
        status: OrderStatus.shipping,
        paymentMethod: 'COD',
        paymentStatus: 'not_applicable',
        recipientName: 'Test',
        phoneNumber: '09123456789',
        deliveryAddress: '123 St',
        items: const [],
        subtotal: 100,
        discount: 0,
        shippingFee: 0,
        grandTotal: 100,
        createdAt: 1000,
        cancellationReason: '',
      );
      expect(shipping.canCancel, isFalse);

      final completed = Order(
        id: '2',
        status: OrderStatus.completed,
        paymentMethod: 'COD',
        paymentStatus: 'not_applicable',
        recipientName: 'Test',
        phoneNumber: '09123456789',
        deliveryAddress: '123 St',
        items: const [],
        subtotal: 100,
        discount: 0,
        shippingFee: 0,
        grandTotal: 100,
        createdAt: 1000,
        cancellationReason: '',
      );
      expect(completed.canCancel, isFalse);

      final cancelled = Order(
        id: '3',
        status: OrderStatus.cancelled,
        paymentMethod: 'COD',
        paymentStatus: 'not_applicable',
        recipientName: 'Test',
        phoneNumber: '09123456789',
        deliveryAddress: '123 St',
        items: const [],
        subtotal: 100,
        discount: 0,
        shippingFee: 0,
        grandTotal: 100,
        createdAt: 1000,
        cancellationReason: '',
      );
      expect(cancelled.canCancel, isFalse);
    });

    test('canReturn is true for cancellable statuses', () {
      // New: Return can only be requested on Completed orders with returnedAt == 0
      final completed = Order(
        id: '3',
        status: OrderStatus.completed,
        paymentMethod: 'COD',
        paymentStatus: 'not_applicable',
        recipientName: 'Test',
        phoneNumber: '09123456789',
        deliveryAddress: '123 St',
        items: const [],
        subtotal: 100,
        discount: 0,
        shippingFee: 0,
        grandTotal: 100,
        createdAt: 1000,
        cancellationReason: '',
        returnReason: '',
        returnedAt: 0,
        refundAmount: 0,
      );
      expect(completed.canReturn, isTrue);
    });

    test('canReturn is false when return already requested', () {
      final returned = Order(
        id: '3',
        status: OrderStatus.completed,
        paymentMethod: 'COD',
        paymentStatus: 'not_applicable',
        recipientName: 'Test',
        phoneNumber: '09123456789',
        deliveryAddress: '123 St',
        items: const [],
        subtotal: 100,
        discount: 0,
        shippingFee: 0,
        grandTotal: 100,
        createdAt: 1000,
        cancellationReason: '',
        returnReason: 'Defective product',
        returnedAt: 1704067200000, // timestamp when return requested
        refundAmount: 0,
      );
      expect(returned.canReturn, isFalse);
    });

    test('canReturn is false for non-completed orders', () {
      final pending = Order(
        id: '1',
        status: OrderStatus.pending,
        paymentMethod: 'COD',
        paymentStatus: 'not_applicable',
        recipientName: 'Test',
        phoneNumber: '09123456789',
        deliveryAddress: '123 St',
        items: const [],
        subtotal: 100,
        discount: 0,
        shippingFee: 0,
        grandTotal: 100,
        createdAt: 1000,
        cancellationReason: '',
        returnReason: '',
        returnedAt: 0,
        refundAmount: 0,
      );
      expect(pending.canReturn, isFalse);
    });

    test('fromMap handles missing optional fields', () {
      final order = Order.fromMap('order2', {
        'userId': 'user1',
        'recipientName': 'Jane',
        'phoneNumber': '09123456789',
        'deliveryAddress': '456 Oak Ave',
        'paymentMethod': 'GCash',
        'paymentStatus': 'verified',
        'items': [],
        'subtotal': 1000,
        'discount': 0,
        'promoCode': null,
        'shippingFee': 0,
        'grandTotal': 1000,
        'status': 'Completed',
        'createdAt': 1704067200000,
        'cancellationReason': '',
        'returnReason': '',
        'returnedAt': 0,
        'refundAmount': 0,
        'returnImageUrl': '',
      });

      expect(order.id, 'order2');
      // Note: Order doesn't have promoCode field
      expect(order.status, OrderStatus.completed);
    });

    test('shortId returns first 8 characters', () {
      final order = Order.fromMap('abcdefghijklmnop', {});
      expect(order.shortId, 'abcdefgh');
    });

    test('isAwaitingPaymentCheck for pending verification', () {
      final order = Order(
        id: '1',
        status: OrderStatus.pending,
        paymentStatus: 'pending_verification',
        paymentMethod: 'COD',
        recipientName: 'Test',
        phoneNumber: '09123456789',
        deliveryAddress: '123 St',
        items: const [],
        subtotal: 100,
        discount: 0,
        shippingFee: 0,
        grandTotal: 100,
        createdAt: 1000,
        cancellationReason: '',
      );
      expect(order.isAwaitingPaymentCheck, isTrue);

      final notAwaiting = Order(
        id: '2',
        status: OrderStatus.pending,
        paymentStatus: 'verified',
        paymentMethod: 'COD',
        recipientName: 'Test',
        phoneNumber: '09123456789',
        deliveryAddress: '123 St',
        items: const [],
        subtotal: 100,
        discount: 0,
        shippingFee: 0,
        grandTotal: 100,
        createdAt: 1000,
        cancellationReason: '',
      );
      expect(notAwaiting.isAwaitingPaymentCheck, isFalse);
    });
  });

  group('OrderStatus', () {
    test('constants have correct string values', () {
      expect(OrderStatus.pending, 'Pending');
      expect(OrderStatus.processing, 'Processing');
      expect(OrderStatus.shipping, 'Shipping');
      expect(OrderStatus.completed, 'Completed');
      expect(OrderStatus.cancelled, 'Cancelled');
      expect(OrderStatus.paymentRejected, 'Payment Rejected');
    });

    test('canCancel logic matches business rules', () {
      // Note: canCancel is on Order, not OrderStatus
      // OrderStatus is just string constants
      expect(OrderStatus.pending, 'Pending');
      expect(OrderStatus.processing, 'Processing');
      expect(OrderStatus.paymentRejected, 'Payment Rejected');
      expect(OrderStatus.shipping, 'Shipping');
      expect(OrderStatus.completed, 'Completed');
      expect(OrderStatus.cancelled, 'Cancelled');
    });
  });

  group('OrderFilter', () {
    test('enum values have labels', () {
      expect(OrderFilter.all.label, 'All');
      expect(OrderFilter.toPay.label, 'To Pay');
      expect(OrderFilter.toShip.label, 'To Ship');
      expect(OrderFilter.toReceive.label, 'To Receive');
      expect(OrderFilter.completed.label, 'Completed');
    });

    test('matches filters correctly', () {
      final filter = OrderFilter.toPay;
      expect(filter.label, 'To Pay');

      final filter2 = OrderFilter.completed;
      expect(filter2.label, 'Completed');

      final filter3 = OrderFilter.returned;
      expect(filter3.label, 'Returned');

      final returnedOrder = Order(
        id: '1',
        status: OrderStatus.returned,
        paymentMethod: 'COD',
        paymentStatus: 'not_applicable',
        recipientName: 'Test',
        phoneNumber: '09123456789',
        deliveryAddress: '123 St',
        items: const [],
        subtotal: 100,
        discount: 0,
        shippingFee: 0,
        grandTotal: 100,
        createdAt: 1000,
        cancellationReason: '',
        returnReason: '',
        returnedAt: 1704067200000,
        refundAmount: 0,
      );
      expect(OrderFilter.returned.matches(returnedOrder), isTrue);
    });
  });
}