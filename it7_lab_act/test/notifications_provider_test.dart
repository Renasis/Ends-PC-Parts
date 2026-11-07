import 'package:flutter_test/flutter_test.dart';
import 'package:it7_lab_act/features/notifications/models/app_notification.dart';

void main() {
  group('AppNotification', () {
    test('fromMap reads all fields', () {
      final notification = AppNotification.fromMap('n1', {
        'title': 'Order Update',
        'message': 'Your order is shipping',
        'type': 'order',
        'orderId': 'order123',
        'productId': 'p1',
        'timestamp': 1704067200000,
        'read': false,
      });

      expect(notification.id, 'n1');
      expect(notification.title, 'Order Update');
      expect(notification.message, 'Your order is shipping');
      expect(notification.kind.name, 'order');
      expect(notification.orderId, 'order123');
      expect(notification.productId, 'p1');
      expect(notification.timestamp, 1704067200000);
      expect(notification.isRead, false);
    });

    test('fromMap handles missing optional fields', () {
      final notification = AppNotification.fromMap('n2', {
        'title': 'Test',
        'message': 'Message',
        'type': 'price',
        'timestamp': 1000,
      });

      expect(notification.id, 'n2');
      expect(notification.title, 'Test');
      expect(notification.message, 'Message');
      expect(notification.kind.name, 'price');
      expect(notification.orderId, '');
      expect(notification.productId, '');
      expect(notification.timestamp, 1000);
      expect(notification.isRead, false); // default
    });

    test('fromMap handles missing read field', () {
      final notification = AppNotification.fromMap('n3', {
        'title': 'Test',
        'message': 'Message',
        'type': 'order',
        'timestamp': 1000,
        'read': true,
      });

      expect(notification.isRead, true);
    });

    test('NotificationKind enum has correct values', () {
      expect(NotificationKind.values, [NotificationKind.order, NotificationKind.price, NotificationKind.general]);
    });
  });
}