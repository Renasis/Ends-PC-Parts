import '../../../core/utils/map_parsing.dart';

enum NotificationKind { order, price, general }

/// One entry at `notifications/{uid}/{id}`, written by the admin dashboard.
///
/// Fields: title, message, type ("order" | "price"), orderId, productId,
/// timestamp (milliseconds since epoch) and read.
class AppNotification {
  final String id;
  final String title;
  final String message;
  final NotificationKind kind;
  final String orderId;
  final String productId;
  final int timestamp;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.kind,
    required this.orderId,
    required this.productId,
    required this.timestamp,
    required this.isRead,
  });

  factory AppNotification.fromMap(String id, Map<dynamic, dynamic> map) {
    return AppNotification(
      id: id,
      title: readText(map['title'], fallback: 'Notification'),
      message: readText(map['message']),
      kind: _kindOf(readText(map['type'])),
      orderId: readText(map['orderId']),
      productId: readText(map['productId']),
      timestamp: readInt(map['timestamp']),
      isRead: map['read'] == true,
    );
  }

  static NotificationKind _kindOf(String type) {
    switch (type) {
      case 'order':
        return NotificationKind.order;
      case 'price':
        return NotificationKind.price;
      default:
        return NotificationKind.general;
    }
  }
}
