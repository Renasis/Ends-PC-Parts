import '../../../core/utils/map_parsing.dart';

/// One line of an order, saved under `transactions/{id}/items`.
class OrderItem {
  final String productId;
  final String productName;
  final int quantity;
  final double price;

  /// Selected variant label (e.g., "Size: Large"), empty when no variants.
  final String variantSelection;

  const OrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    this.variantSelection = '',
  });

  factory OrderItem.fromMap(Map<dynamic, dynamic> map) {
    return OrderItem(
      productId: readText(map['productId']),
      productName: readText(map['productName'], fallback: 'Product'),
      quantity: readInt(map['quantity']),
      price: readNumber(map['price']),
      variantSelection: readText(map['variantSelection']),
    );
  }

  double get lineTotal => price * quantity;
}