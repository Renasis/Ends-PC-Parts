/// The `status` and `paymentStatus` values saved on `transactions/{id}`.
///
/// They match what the app writes at checkout and what the admin dashboard
/// sets in orders.js and verification.js.
abstract final class OrderStatus {
  static const pending = 'Pending';
  static const processing = 'Processing';
  static const shipping = 'Shipping';
  static const completed = 'Completed';
  static const cancelled = 'Cancelled';
  static const paymentRejected = 'Payment Rejected';
  static const returned = 'Returned';
}

/// Who cancelled an order: the `cancelledBy` value on `transactions/{id}`.
abstract final class CancelledBy {
  static const customer = 'customer';
  static const admin = 'admin';
}

/// Who completed an order: the `completedBy` value on `transactions/{id}`.
/// Empty on orders the admin completed.
abstract final class CompletedBy {
  /// The customer tapped "Order received".
  static const customer = 'customer';

  /// The app completed it because the estimated delivery passed long enough ago.
  static const auto = 'auto';
}

/// The `returnStatus` values saved on `transactions/{id}`.
abstract final class ReturnStatus {
  static const requested = 'requested';
  static const approved = 'approved';
  static const rejected = 'rejected';
}

abstract final class PaymentStatus {
  /// Admin checked the payment proof and accepted it.
  static const verified = 'verified';
  /// Admin refused the payment proof.
  static const rejected = 'rejected';
  /// Online payment: proof submitted, waiting for the admin to check it.
  static const pendingVerification = 'pending_verification';
  /// Admin approved return, refund to be processed.
  static const refundPending = 'refund_pending';
  /// Refund completed.
  static const refunded = 'refunded';
}