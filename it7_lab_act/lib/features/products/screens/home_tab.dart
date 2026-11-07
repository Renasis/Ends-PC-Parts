import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/error_state.dart';
import '../providers/product_provider.dart';
import '../widgets/category_shortcuts.dart';
import '../widgets/featured_carousel.dart';
import '../widgets/product_grid.dart';

/// Body of the "Home" tab (no Scaffold of its own).
class HomeTab extends StatelessWidget {
  /// Switches the home screen to the Shop tab.
  final VoidCallback onShopNow;

  const HomeTab({super.key, required this.onShopNow});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final products = provider.products;

    if (provider.isLoading && products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.errorMessage.isNotEmpty && products.isEmpty) {
      return ErrorState(
        message: provider.errorMessage,
        onRetry: provider.retry,
      );
    }
    if (products.isEmpty) {
      return const Center(child: Text('No products available yet.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          FeaturedCarousel(products: products.take(5).toList()),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CategoryShortcuts(
              onSelected: (category) {
                provider.setCategory(category);
                onShopNow();
              },
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Daily Discover',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    provider.resetFilters();
                    onShopNow();
                  },
                  child: const Text('See All >'),
                ),
              ],
            ).animate().fadeIn().slideX(begin: -0.1, end: 0),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ProductGrid(products: products, shrinkWrap: true),
          ),
        ],
      ),
    );
  }
}