import '../../cart/models/cart_item.dart';
import '../../products/models/product.dart';

/// Result of re-checking the order's items against the live product data.
class OrderCheckResult {
  /// The items with the latest product data. Unavailable ones are removed and
  /// quantities are reduced to the available stock.
  final List<CartItem> items;

  /// Latest data for every product that still exists.
  final Map<String, Product> latest;

  /// Plain-language descriptions of everything that changed.
  final List<String> messages;

  const OrderCheckResult({
    required this.items,
    required this.latest,
    required this.messages,
  });

  bool get changed => messages.isNotEmpty;
}