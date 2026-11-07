import 'package:flutter/material.dart';
import '../../../core/widgets/product_image.dart';
import 'package:provider/provider.dart';
import '../providers/wishlist_provider.dart';
import '../../products/providers/product_provider.dart';
// Import your ProductCard or whatever UI you use to display a single product
// import '../../products/widgets/product_card.dart'; 

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wishlistProvider = context.watch<WishlistProvider>();
    final productProvider = context.watch<ProductProvider>();

    // Filter all products to only those whose IDs are in the wishlist
    final favoriteProducts = productProvider.products
        .where((p) => wishlistProvider.isFavorite(p.id))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wishlist'),
      ),
      body: wishlistProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : wishlistProvider.errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 56, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(
                        wishlistProvider.errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          wishlistProvider.clearWishlistState();
                          // Trigger a re-listen by briefly setting user to null then back
                          // The auth state listener will re-fetch automatically
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : favoriteProducts.isEmpty
              ? const Center(
                  child: Text(
                    'Your wishlist is empty.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: favoriteProducts.length,
                  itemBuilder: (context, index) {
                    final product = favoriteProducts[index];
                    
                    // Replace this ListTile with your actual ProductCard widget
                    return Card(
                      child: ListTile(
                        leading: ProductImage(product.imageUrl, width: 50, height: 50),
                        title: Text(product.name), // or productName depending on your model
                        subtitle: Text('₱${product.price.toStringAsFixed(2)}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () {
                            wishlistProvider.toggleFavorite(product.id);
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}