import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/product.dart';
import 'product_card.dart';

/// Two-column grid of [ProductCard]s.
///
/// With [shrinkWrap] it sits inside another scroll view (the Home tab);
/// otherwise it scrolls on its own (the Shop tab).
class ProductGrid extends StatelessWidget {
  final List<Product> products;
  final bool shrinkWrap;

  const ProductGrid({
    super.key,
    required this.products,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: shrinkWrap ? EdgeInsets.zero : const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        childAspectRatio: 0.68,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        return ProductCard(product: products[index])
            .animate(delay: ((index < 8 ? index : 8) * 40).ms)
            .fadeIn(duration: 250.ms)
            .scale(begin: const Offset(0.95, 0.95));
      },
    );
  }
}