import '../../products/models/product.dart';

class CartItem {
  final Product product;
  int quantity;

  /// Selected variant label (e.g., "Size: Large"), empty when no variants.
  final String variantSelection;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.variantSelection = '',
  });

  double get totalPrice => product.priceForVariant(variantSelection) * quantity;

  /// Effective stock for the selected variant.
  int get effectiveStock => product.stockForVariant(variantSelection);
}