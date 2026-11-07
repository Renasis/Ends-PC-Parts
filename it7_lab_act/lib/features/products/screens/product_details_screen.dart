import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../account/utils/profile_gate.dart';
import '../../auth/require_login.dart';
import '../../cart/models/cart_item.dart';
import '../../cart/providers/cart_provider.dart';
import '../../cart/screens/cart_screen.dart';
import '../../checkout/screens/checkout_screen.dart';
import '../../reviews/providers/reviews_provider.dart';
import '../../reviews/widgets/reviews_section.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';
import '../widgets/product_bottom_bar.dart';
import '../widgets/product_image_header.dart';
import '../widgets/product_info.dart';
import '../widgets/quantity_selector.dart';
import '../widgets/wishlist_button.dart';

class ProductDetailsScreen extends StatefulWidget {
  final String productId;

  const ProductDetailsScreen({super.key, required this.productId});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  int _quantity = 1;
  String? _selectedVariant;

  void _addToCart(Product product, int quantity) {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final colors = Theme.of(context).colorScheme;
    final error =
        context.read<CartProvider>().addItem(product, quantity: quantity, variantSelection: _selectedVariant ?? '');

    messenger.hideCurrentSnackBar();
    if (error != null) {
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: colors.error,
          content: Text(error, style: TextStyle(color: colors.onError)),
        ),
      );
      return;
    }

    setState(() => _quantity = 1);
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        content: Text('Added $quantity x ${product.name} to cart'),
        action: SnackBarAction(
          label: 'VIEW CART',
          onPressed: () => navigator.push(
            MaterialPageRoute(builder: (_) => const CartScreen()),
          ),
        ),
      ),
    );
  }

  Future<void> _buyNow(Product product, int quantity) async {
    final navigator = Navigator.of(context);
    if (!await ensureLoggedIn(context)) return;
    if (!mounted || !await ensureProfileComplete(context)) return;
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          buyNowItems: [CartItem(product: product, quantity: quantity, variantSelection: _selectedVariant ?? '')],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductProvider>();
    final product = products.findById(widget.productId);
    final inCart = context.select<CartProvider, int>(
      (cart) => cart.items[widget.productId]?.quantity ?? 0,
    );

    if (product == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: products.isLoading
              ? const CircularProgressIndicator()
              : const Text('This product is no longer available.'),
        ),
      );
    }

    // Clamp _quantity to valid range (1..effective stock) whenever product/stock changes
    final effectiveStock = product.stockForVariant(_selectedVariant ?? '');
    if (_quantity > effectiveStock) {
      _quantity = effectiveStock.clamp(1, effectiveStock);
    } else if (_quantity < 1) {
      _quantity = 1;
    }

    final inStock = effectiveStock > 0;
    final quantity = _quantity; // Already clamped above
    final unitPrice = product.priceForVariant(_selectedVariant ?? '');

    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
        actions: [WishlistButton(productId: product.id)],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProductImageHeader(
              productId: product.id,
              thumbnail: product.imageUrl,
              imageUrls: product.imageUrls,
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProductInfo(product: product),
                  if (product.variantOptions.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedVariant,
                      decoration: const InputDecoration(
                        labelText: 'Variant',
                        border: OutlineInputBorder(),
                      ),
                      items: product.variantOptions.map((v) {
                        final label = v['label'] as String?;
                        final adjustment = (v['priceAdjustment'] as num?) ?? 0;
                        final stock = (v['stock'] as num?) ?? 0;
                        return DropdownMenuItem<String>(
                          value: label,
                          child: Text(
                            stock > 0
                                ? '$label (+₱${adjustment.toStringAsFixed(2)})'
                                : '$label (out of stock)',
                            style: TextStyle(
                              color: stock > 0 ? null : Colors.grey,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: product.variantOptions.any((v) => ((v['stock'] as num?) ?? 0) > 0)
                          ? (value) => setState(() => _selectedVariant = value)
                          : null,
                    ),
                  ],
                  if (inStock) ...[
                    const SizedBox(height: 24),
                    QuantitySelector(
                      quantity: quantity,
                      max: effectiveStock,
                      inCart: inCart,
                      onChanged: (value) => setState(() => _quantity = value),
                    ),
                  ],
                  const Divider(height: 32),
                  ChangeNotifierProvider(
                    create: (_) => ReviewsProvider(widget.productId),
                    child: const ReviewsSection(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: ProductBottomBar(
        total: unitPrice * quantity,
        inStock: inStock,
        onAddToCart: inStock ? () => _addToCart(product, quantity) : null,
        onBuyNow: inStock ? () => _buyNow(product, quantity) : null,
      ),
    );
  }
}
