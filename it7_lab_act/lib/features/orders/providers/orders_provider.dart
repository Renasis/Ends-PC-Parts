import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../models/order.dart';
import '../models/order_filter.dart';
import '../models/order_status.dart';
import '../../cart/models/cart_item.dart';
import '../../products/models/product.dart';

/// The signed-in customer's orders, kept live from `transactions`.
///
/// Created once in main.dart and re-pointed at the current user with
/// [bindUser] whenever the login state changes.
class OrdersProvider extends ChangeNotifier {
  static const _loadError =
      'Could not load your orders. Please check your connection and try again.';

  /// Days after the estimated delivery before a shipped order completes by
  /// itself, unless the admin set `settings/autoCompleteDays`.
  static const defaultAutoCompleteDays = 3;

  final DatabaseReference _root = FirebaseDatabase.instance.ref();
  late final DatabaseReference _transactions = _root.child('transactions');

  StreamSubscription<DatabaseEvent>? _sub;
  String? _userId;
  List<Order> _orders = const [];
  bool _isLoading = false;
  String _errorMessage = '';
  bool _disposed = false;

  /// Orders the app already tried to auto-complete, so one failure is not
  /// retried on every database update.
  final Set<String> _autoCompleteTried = {};
  int? _autoCompleteDays;

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;

  /// Non-empty when the orders could not be loaded.
  String get errorMessage => _errorMessage;

  List<Order> ordersFor(OrderFilter filter) =>
      _orders.where(filter.matches).toList();

  int countFor(OrderFilter filter) => _orders.where(filter.matches).length;

  /// Starts listening for [userId]'s orders, or clears everything when null.
  /// Safe to call on every auth change: the same user is a no-op.
  void bindUser(String? userId) {
    if (userId == _userId) return;

    _sub?.cancel();
    _sub = null;
    _userId = userId;
    _autoCompleteTried.clear();
    _orders = const [];
    _errorMessage = '';
    _isLoading = userId != null;

    if (userId != null) _listen(userId);

    // Called while the widget tree is building, so notify after the frame.
    scheduleMicrotask(notifyListeners);
  }

  /// Restarts the listener after a failed load.
  void retry() {
    final userId = _userId;
    _userId = null;
    bindUser(userId);
  }

  void _listen(String userId) {
    _sub = _transactions
        .orderByChild('userId')
        .equalTo(userId)
        .onValue
        .listen((event) {
      final raw = event.snapshot.value;
      final loaded = <Order>[];
      if (raw is Map) {
        raw.forEach((key, value) {
          if (value is Map) loaded.add(Order.fromMap(key.toString(), value));
        });
      }
      loaded.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _orders = loaded;
      _errorMessage = '';
      _isLoading = false;
      notifyListeners();
      _autoCompleteDueOrders(loaded);
    }, onError: (Object _) {
      _errorMessage = _loadError;
      _isLoading = false;
      notifyListeners();
    });
  }

  /// Returns null on success, otherwise a message to show the customer.
  ///
  /// [reason] is what the customer picked or typed; it is saved as the
  /// order's `cancellationReason` so the admin can see it.
  Future<String?> cancelOrder(Order order, String reason) async {
    if (!order.canCancel) return 'This order can no longer be cancelled.';
    final trimmed = reason.trim();
    if (trimmed.isEmpty) return 'Please tell us why you are cancelling.';
    if (trimmed.length > 220) return 'Reason is too long.';
    try {
      final updates = <String, dynamic>{
        'status': OrderStatus.cancelled,
        'cancellationReason': trimmed,
        'cancelledBy': CancelledBy.customer,
      };
      // Older orders kept the payment-rejection reason in cancellationReason.
      // Save it in its own field before it is replaced.
      if (order.status == OrderStatus.paymentRejected &&
          order.paymentRejectionReason.isEmpty &&
          order.cancellationReason.isNotEmpty) {
        updates['paymentRejectionReason'] = order.cancellationReason;
      }
      await _transactions.child(order.id).update(updates);
      return null;
    } on FirebaseException catch (e) {
      return e.code == 'permission-denied'
          ? 'You are not allowed to cancel this order.'
          : 'Could not cancel the order. Please try again.';
    } catch (e) {
      debugPrint('OrdersProvider: $e');
      return 'Could not cancel the order. Please try again.';
    }
  }

  /// The customer confirms the order arrived: Shipping -> Completed.
  /// Returns null on success, otherwise a message to show the customer.
  Future<String?> markReceived(Order order) async {
    if (!order.canMarkReceived) return 'This order is not on its way.';
    return _complete(order, CompletedBy.customer);
  }

  /// Completes shipped orders whose estimated delivery passed more than
  /// `settings/autoCompleteDays` ago. There are no Cloud Functions, so this
  /// runs whenever the customer's orders load; the admin dashboard does the
  /// same check for customers who do not open the app.
  Future<void> _autoCompleteDueOrders(List<Order> orders) async {
    final candidates = orders
        .where((o) => o.canMarkReceived && o.estimatedDelivery > 0)
        .where((o) => !_autoCompleteTried.contains(o.id))
        .toList();
    if (candidates.isEmpty) return;

    final days = await _loadAutoCompleteDays();
    for (final order in candidates) {
      if (_disposed) return;
      if (!order.isDueForAutoComplete(days)) continue;
      _autoCompleteTried.add(order.id);
      await _complete(order, CompletedBy.auto);
    }
  }

  Future<int> _loadAutoCompleteDays() async {
    final cached = _autoCompleteDays;
    if (cached != null) return cached;
    try {
      final value = (await _root.child('settings/autoCompleteDays').get()).value;
      final days = value is num ? value.toInt() : defaultAutoCompleteDays;
      return _autoCompleteDays = days < 0 ? defaultAutoCompleteDays : days;
    } catch (e) {
      debugPrint('OrdersProvider: $e');
      return defaultAutoCompleteDays;
    }
  }

  /// Saves Completed on the order. Reviews need no extra marker: the database
  /// rules check the Completed order itself. Returns null on success,
  /// otherwise a message for the customer.
  Future<String?> _complete(Order order, String completedBy) async {
    try {
      await _transactions.child(order.id).update({
        'status': OrderStatus.completed,
        'completedAt': DateTime.now().millisecondsSinceEpoch,
        'completedBy': completedBy,
      });
    } on FirebaseException catch (e) {
      debugPrint('OrdersProvider: ${e.code} ${e.message}');
      // The order may have been completed or cancelled by the store a moment
      // ago; the live listener will show its real state.
      return e.code == 'permission-denied'
          ? 'This order was just updated by the store. Please check its status.'
          : 'Could not update the order. Please try again.';
    } catch (e) {
      debugPrint('OrdersProvider: $e');
      return 'Could not update the order. Please try again.';
    }

    return null;
  }

  /// Marks the order as having a return request. The admin reviews it and
  /// later sets the refund amount + refund status.
  ///
  /// [reason] is the customer's stated reason for the return.
  /// [returnImageUrl] is an optional base64 data URL of a return proof image.
  /// [refundMethod], [accountName] and [accountNumber] say where the shop
  /// should send the refund if the return is approved.
  ///
  /// Returns null on success, otherwise a message to show the customer.
  Future<String?> requestReturn(
    Order order,
    String reason, {
    String returnImageUrl = '',
    required String refundMethod,
    required String accountName,
    required String accountNumber,
  }) async {
    if (!order.canReturn) return 'This order can no longer be returned.';
    final trimmed = reason.trim();
    if (trimmed.isEmpty) return 'Please tell us why you want to return this order.';
    if (trimmed.length > 500) return 'Reason is too long. Please keep it under 500 characters.';
    if (refundMethod.trim().isEmpty ||
        accountName.trim().isEmpty ||
        accountNumber.trim().isEmpty) {
      return 'Please tell us where to send your refund.';
    }
    try {
      final updates = <String, dynamic>{
        'returnReason': trimmed,
        'returnedAt': DateTime.now().millisecondsSinceEpoch,
        'returnStatus': ReturnStatus.requested,
        'refundMethod': refundMethod.trim(),
        'refundAccountName': accountName.trim(),
        'refundAccountNumber': accountNumber.trim(),
      };
      if (returnImageUrl.isNotEmpty) {
        updates['returnImageUrl'] = returnImageUrl;
      }
      await _transactions.child(order.id).update(updates);
      return null;
    } on FirebaseException catch (e) {
      return e.code == 'permission-denied'
          ? 'You are not allowed to return this order.'
          : 'Could not submit your return request. Please try again.';
    } catch (e) {
      debugPrint('OrdersProvider: $e');
      return 'Could not submit your return request. Please try again.';
    }
  }

  /// Builds [CartItem]s from a past order so they can be added back to the cart.
  /// Looks up each product from `products/{id}` to get current price/stock.
  Future<List<CartItem>> buildReorderItems(Order order) async {
    final items = <CartItem>[];
    for (final item in order.items) {
      final snap = await FirebaseDatabase.instance.ref().child('products').child(item.productId).get();
      if (snap.value is Map) {
        final product = Product.fromMap(item.productId, snap.value as Map);
        items.add(CartItem(
          product: product,
          quantity: item.quantity,
          variantSelection: item.variantSelection,
        ));
      }
    }
    return items;
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }
}