import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../orders/models/order.dart';
import '../../orders/models/order_status.dart';
import '../models/review.dart';

enum ReviewEligibility { allowed, notPurchased, failed }

/// Reviews of one product, kept live from `products/{productId}/reviews`.
///
/// Created by the product details screen, so it lives only while that
/// screen is open.
class ReviewsProvider extends ChangeNotifier {
  static const _loadError =
      'Could not load reviews. Please check your connection and try again.';

  final String productId;
  final DatabaseReference _reviewsRef;

  StreamSubscription<DatabaseEvent>? _sub;
  List<Review> _reviews = const [];
  bool _isLoading = true;
  String _errorMessage = '';
  bool _disposed = false;

  ReviewsProvider(this.productId)
      : _reviewsRef = FirebaseDatabase.instance
            .ref()
            .child('products')
            .child(productId)
            .child('reviews') {
    _listen();
  }

  List<Review> get reviews => _reviews;
  bool get isLoading => _isLoading;

  /// Non-empty when the reviews could not be loaded.
  String get errorMessage => _errorMessage;

  double get averageRating {
    if (_reviews.isEmpty) return 0;
    final total = _reviews.fold<double>(0, (sum, r) => sum + r.rating);
    return total / _reviews.length;
  }

  void _listen() {
    _sub = _reviewsRef.onValue.listen((event) {
      final raw = event.snapshot.value;
      final loaded = <Review>[];
      if (raw is Map) {
        raw.forEach((key, value) {
          if (value is Map) loaded.add(Review.fromMap(key.toString(), value));
        });
      }
      loaded.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _reviews = loaded;
      _errorMessage = '';
      _isLoading = false;
      notifyListeners();
    }, onError: (Object _) {
      _errorMessage = _loadError;
      _isLoading = false;
      notifyListeners();
    });
  }

  /// Restarts the listener after a failed load.
  void retry() {
    _sub?.cancel();
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    _listen();
  }

  /// The order that proves the purchase. It is saved with the review so the
  /// database rules can check it too.
  String? _eligibleOrderId;

  /// Only customers with a Completed order containing this product may review.
  Future<ReviewEligibility> checkEligibility(String userId) async {
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref()
          .child('transactions')
          .orderByChild('userId')
          .equalTo(userId)
          .get();
      final raw = snapshot.value;
      if (raw is Map) {
        for (final entry in raw.entries) {
          final value = entry.value;
          if (value is! Map) continue;
          final order = Order.fromMap(entry.key.toString(), value);
          final boughtIt =
              order.items.any((item) => item.productId == productId);
          if (order.status == OrderStatus.completed && boughtIt) {
            _eligibleOrderId = entry.key.toString();
            return ReviewEligibility.allowed;
          }
        }
      }
      return ReviewEligibility.notPurchased;
    } catch (_) {
      return ReviewEligibility.failed;
    }
  }

  /// Returns true when the review was saved.
  Future<bool> addReview({
    required String userId,
    required String userName,
    required double rating,
    required String comment,
  }) async {
    final orderId = _eligibleOrderId;
    if (orderId == null) return false;
    try {
      // The rules require the review's key to be the customer's own uid
      // (one review per product per customer) and the orderId of a
      // Completed order of theirs that contains this product.
      await _reviewsRef.child(userId).set({
        'userId': userId,
        'orderId': orderId,
        'userName': userName,
        'rating': rating,
        'comment': comment,
        'timestamp': ServerValue.timestamp,
      });
      return true;
    } catch (_) {
      return false;
    }
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