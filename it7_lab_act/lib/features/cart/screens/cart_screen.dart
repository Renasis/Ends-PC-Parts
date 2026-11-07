import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/product_image.dart';
import '../../account/utils/profile_gate.dart';
import '../../auth/require_login.dart';
import '../providers/cart_provider.dart';
import '../../checkout/screens/checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  Future<void> _goToCheckout(BuildContext context) async {
    final navigator = Navigator.of(context);
    if (!await ensureLoggedIn(context)) return;
    if (!context.mounted || !await ensureProfileComplete(context)) return;
    await navigator.push(
      MaterialPageRoute(builder: (_) => const CheckoutScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final cartItems = cart.items.values.toList();
    final allSelected = cartItems.isNotEmpty && cart.selectedIds.length == cartItems.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Cart'),
        actions: [
          if (cartItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () => cart.clearCart(),
              tooltip: 'Clear Cart',
            ),
        ],
      ),
      body: cartItems.isEmpty
          ? _EmptyCart(cart: cart)
          : Column(
              children: [
                if (cart.syncError.isNotEmpty) _SyncBanner(cart: cart),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: Row(
                    children: [
                      Checkbox(
                        value: allSelected,
                        onChanged: (val) => cart.toggleSelectAll(val ?? false),
                      ),
                      const Text('Select All Items', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      final isChecked = cart.isSelected(item.product.id, variantSelection: item.variantSelection);

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: ListTile(
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: isChecked,
                                onChanged: (_) => cart.toggleSelection(item.product.id, variantSelection: item.variantSelection),
                              ),
                              ProductImage(item.product.imageUrl, width: 50, height: 50),
                            ],
                          ),
                          title: Text(
                            item.variantSelection.isNotEmpty
                                ? '${item.product.name} (${item.variantSelection})'
                                : item.product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text('₱${item.product.priceForVariant(item.variantSelection).toStringAsFixed(2)} x ${item.quantity}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, size: 20),
                                onPressed: () => cart.removeSingleItem(item.product.id, variantSelection: item.variantSelection),
                              ),
                              Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, size: 20),
                                onPressed: () {
                                  final error = cart.addItem(item.product, variantSelection: item.variantSelection);
                                  if (error != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(error)),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Selected (${cart.selectedItemCount} items):', style: const TextStyle(fontSize: 16)),
                            Text(
                              '₱${cart.totalAmount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: cart.selectedIds.isEmpty
                                ? null
                                : () => _goToCheckout(context),
                            child: const Text('Proceed to Checkout'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Shown when the cart has no items: a spinner while the account's saved
/// cart loads, a retry when it failed, otherwise the plain empty message.
class _EmptyCart extends StatelessWidget {
  final CartProvider cart;

  const _EmptyCart({required this.cart});

  @override
  Widget build(BuildContext context) {
    if (cart.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (cart.syncError.isNotEmpty) {
      return ErrorState(message: cart.syncError, onRetry: cart.retrySync);
    }
    return const Center(
      child: Text(
        'Your cart is empty.',
        style: TextStyle(fontSize: 16, color: Colors.grey),
      ),
    );
  }
}

/// Thin warning above the list when the cart could not be saved.
class _SyncBanner extends StatelessWidget {
  final CartProvider cart;

  const _SyncBanner({required this.cart});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: scheme.errorContainer,
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              cart.syncError,
              style: TextStyle(fontSize: 12, color: scheme.onErrorContainer),
            ),
          ),
          TextButton(onPressed: cart.retrySync, child: const Text('Retry')),
        ],
      ),
    );
  }
}