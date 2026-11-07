import 'package:flutter/material.dart';

import '../models/product.dart';

/// Category, stock status, name, price and description.
class ProductInfo extends StatelessWidget {
  /// At or below this many left, the stock label turns into a warning.
  static const _lowStockLimit = 5;

  final Product product;

  const ProductInfo({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final inStock = product.stock > 0;
    final lowStock = inStock && product.stock <= _lowStockLimit;
    final stockColor = !inStock
        ? Colors.red
        : lowStock
            ? Colors.orange.shade800
            : Colors.green;
    final stockText = !inStock
        ? 'Out of Stock'
        : lowStock
            ? 'Only ${product.stock} left'
            : 'In Stock (${product.stock})';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                product.category,
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Row(
              children: [
                Icon(
                  !inStock
                      ? Icons.cancel
                      : lowStock
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle,
                  size: 16,
                  color: stockColor,
                ),
                const SizedBox(width: 4),
                Text(
                  stockText,
                  style: TextStyle(
                    color: stockColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          product.name,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '₱${product.price.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: colors.primary,
          ),
        ),
        const Divider(height: 32),
        const Text(
          'Description',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          product.description.isEmpty
              ? 'No description provided.'
              : product.description,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}