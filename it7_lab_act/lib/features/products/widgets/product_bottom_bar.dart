import 'package:flutter/material.dart';

/// Total price with the Add to Cart and Buy Now buttons.
/// Pass null callbacks to disable the buttons (out of stock).
class ProductBottomBar extends StatelessWidget {
  final double total;
  final bool inStock;
  final VoidCallback? onAddToCart;
  final VoidCallback? onBuyNow;

  const ProductBottomBar({
    super.key,
    required this.total,
    required this.onAddToCart,
    required this.onBuyNow,
    this.inStock = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    const label = TextStyle(fontSize: 15, fontWeight: FontWeight.bold);

    return Material(
      elevation: 8,
      color: colors.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total',
                      style: TextStyle(color: colors.onSurfaceVariant)),
                  inStock
                      ? Text(
                          '₱${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        )
                      : Text(
                          'Currently out of stock',
                          style: TextStyle(
                            color: colors.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: onAddToCart,
                        style: OutlinedButton.styleFrom(shape: shape),
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text('Add to Cart', style: label),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: onBuyNow,
                        style: ElevatedButton.styleFrom(shape: shape),
                        child: const Text('Buy Now', style: label),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
