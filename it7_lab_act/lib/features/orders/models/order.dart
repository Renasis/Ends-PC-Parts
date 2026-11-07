import '../../../core/utils/map_parsing.dart';
import 'order_item.dart';
import 'order_status.dart';

/// An order saved at `transactions/{id}` (see the order data contract).
class Order {
  final String id;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final String recipientName;
  final String phoneNumber;
  final String deliveryAddress;
  final List<OrderItem> items;
  final double subtotal;
  final double discount;
  final double shippingFee;
  final double grandTotal;

  /// Milliseconds since epoch.
  final int createdAt;

  /// Set by the admin (or the customer) when the order is cancelled.
  final String cancellationReason;

  /// Who cancelled the order: 'customer' or 'admin'. Empty on older orders.
  final String cancelledBy;

  /// Why the admin refused the payment proof. Kept apart from
  /// [cancellationReason] so cancelling later does not erase it.
  final String paymentRejectionReason;

  /// Set by the customer when they request a return.
  final String returnReason;

  /// Milliseconds since epoch; 0 when no return has been requested.
  final int returnedAt;

  /// Admin-approved refund amount; 0 when not yet refunded.
  final double refundAmount;

  /// Base64 data URL of the return proof image (optional).
  final String returnImageUrl;

  /// Refund status: 'refund_pending' after admin approves return, 'refunded' when processed.
  final String refundStatus;

  /// Where the return request stands: 'requested' (waiting for the admin),
  /// 'approved' or 'rejected'. Empty when no return was requested.
  final String returnStatus;

  /// The admin's note to the customer (why a return was rejected, or any
  /// instructions on approval).
  final String returnAdminNote;

  /// Where the customer wants the money sent, e.g. 'GCash', 'Maya',
  /// 'Bank Transfer - BPI'. Chosen when the return is requested.
  final String refundMethod;
  final String refundAccountName;
  final String refundAccountNumber;

  /// Transaction/reference number the admin got when sending the refund,
  /// and when it was sent (milliseconds since epoch).
  final String refundReference;
  final int refundedAt;

  /// Shipping tracking info (set by admin when order ships).
  final String shippingCarrier;
  final String trackingNumber;
  final int shippedAt;
  final int estimatedDelivery;

  /// When the order was completed by the customer ("Order received") or
  /// automatically; 0 when the admin completed it or it is not completed.
  final int completedAt;

  /// 'customer' or 'auto' (see [CompletedBy]); empty otherwise.
  final String completedBy;

  /// Free-form admin notes about this order (e.g., "Fragile item, pack carefully").
  final String adminNotes;

  const Order({
    required this.id,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.recipientName,
    required this.phoneNumber,
    required this.deliveryAddress,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.shippingFee,
    required this.grandTotal,
    required this.createdAt,
    required this.cancellationReason,
    this.cancelledBy = '',
    this.paymentRejectionReason = '',
    this.returnReason = '',
    this.returnedAt = 0,
    this.refundAmount = 0,
    this.returnImageUrl = '',
    this.refundStatus = '',
    this.returnStatus = '',
    this.returnAdminNote = '',
    this.refundMethod = '',
    this.refundAccountName = '',
    this.refundAccountNumber = '',
    this.refundReference = '',
    this.refundedAt = 0,
    this.shippingCarrier = '',
    this.trackingNumber = '',
    this.shippedAt = 0,
    this.estimatedDelivery = 0,
    this.completedAt = 0,
    this.completedBy = '',
    this.adminNotes = '',
  });

  factory Order.fromMap(String id, Map<dynamic, dynamic> map) {
    return Order(
      id: id,
      status: readText(map['status'], fallback: OrderStatus.pending),
      paymentMethod: readText(map['paymentMethod'], fallback: 'N/A'),
      paymentStatus: readText(map['paymentStatus']),
      recipientName: readText(map['recipientName'], fallback: 'N/A'),
      phoneNumber: readText(map['phoneNumber'], fallback: 'N/A'),
      deliveryAddress: readText(map['deliveryAddress'], fallback: 'N/A'),
      items: _parseItems(map['items']),
      subtotal: readNumber(map['subtotal']),
      discount: readNumber(map['discount']),
      shippingFee: readNumber(map['shippingFee']),
      grandTotal: readNumber(map['grandTotal']),
      createdAt: readInt(map['createdAt']),
      cancellationReason: readText(map['cancellationReason']),
      cancelledBy: readText(map['cancelledBy']),
      paymentRejectionReason: readText(map['paymentRejectionReason']),
      returnReason: readText(map['returnReason']),
      returnedAt: readInt(map['returnedAt']),
      refundAmount: readNumber(map['refundAmount']),
      returnImageUrl: readText(map['returnImageUrl']),
      refundStatus: readText(map['refundStatus']),
      returnStatus: readText(map['returnStatus']),
      returnAdminNote: readText(map['returnAdminNote']),
      refundMethod: readText(map['refundMethod']),
      refundAccountName: readText(map['refundAccountName']),
      refundAccountNumber: readText(map['refundAccountNumber']),
      refundReference: readText(map['refundReference']),
      refundedAt: readInt(map['refundedAt']),
      shippingCarrier: readText(map['shippingCarrier']),
      trackingNumber: readText(map['trackingNumber']),
      shippedAt: readInt(map['shippedAt']),
      estimatedDelivery: readInt(map['estimatedDelivery']),
      completedAt: readInt(map['completedAt']),
      completedBy: readText(map['completedBy']),
      adminNotes: readText(map['adminNotes']),
    );
  }

  /// Firebase returns an array as a `List`, but a `Map` if keys were sparse.
  static List<OrderItem> _parseItems(Object? raw) {
    final values = raw is List
        ? raw
        : raw is Map
            ? raw.values
            : const <Object?>[];
    return [
      for (final value in values)
        if (value is Map) OrderItem.fromMap(value),
    ];
  }

  /// First 8 characters, enough for the customer to quote to the shop.
  String get shortId => id.length > 8 ? id.substring(0, 8) : id;

  /// Total quantity across all lines.
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  /// Where the payment stands, in words for the customer. Empty when there
  /// is nothing useful to say (for example a cancelled order).
  String get paymentStatusLabel {
    if (isRefunded) return 'Refunded';
    if (refundStatus == PaymentStatus.refundPending) return 'Refund pending';
    if (status == OrderStatus.cancelled) return '';

    switch (paymentStatus) {
      case PaymentStatus.pendingVerification:
        return 'Awaiting verification';
      case PaymentStatus.verified:
        return 'Paid';
      case PaymentStatus.rejected:
        return 'Payment rejected';
    }
    if (status == OrderStatus.completed) return 'Paid';
    return originalOnlineMethod == null ? 'Pay on delivery' : '';
  }

  /// Why the payment was rejected. Orders rejected before the separate field
  /// existed kept the reason in [cancellationReason], so fall back to that.
  String get paymentRejectionText {
    if (paymentRejectionReason.isNotEmpty) return paymentRejectionReason;
    return status == OrderStatus.paymentRejected ? cancellationReason : '';
  }

  bool get isAwaitingPaymentCheck =>
      paymentStatus == PaymentStatus.pendingVerification;

  /// Nothing has been deducted from stock yet in these two states, so the
  /// customer can cancel without the admin having to restore anything.
  bool get canCancel =>
      status == OrderStatus.pending || status == OrderStatus.paymentRejected;

  /// While the order is on its way the customer can confirm it arrived.
  bool get canMarkReceived => status == OrderStatus.shipping;

  /// True when the estimated delivery date is more than [graceDays] days
  /// ago, so the app may complete the order on the customer's behalf. Needs
  /// an estimated delivery date; without one the order is never auto-completed.
  bool isDueForAutoComplete(int graceDays, {DateTime? now}) {
    if (!canMarkReceived || estimatedDelivery <= 0) return false;
    final due = DateTime.fromMillisecondsSinceEpoch(estimatedDelivery)
        .add(Duration(days: graceDays));
    return (now ?? DateTime.now()).isAfter(due);
  }

  /// Returns can only be requested on Completed orders.
  bool get canReturn =>
      status == OrderStatus.completed && returnedAt == 0;

  /// The customer asked for a return and the admin has not decided yet.
  bool get isReturnAwaitingReview =>
      returnedAt > 0 &&
      status == OrderStatus.completed &&
      returnStatus != ReturnStatus.rejected;

  bool get isReturnRejected => returnStatus == ReturnStatus.rejected;

  bool get isRefunded => refundStatus == PaymentStatus.refunded;

  /// The online payment method this order was paid with, or null for COD.
  /// Used to offer "refund to the same account" in the return dialog.
  String? get originalOnlineMethod =>
      paymentMethod.toLowerCase() == 'cod' || paymentMethod == 'N/A'
          ? null
          : paymentMethod;
}