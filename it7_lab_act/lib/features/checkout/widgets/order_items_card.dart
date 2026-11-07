import 'package:flutter/material.dart';

import '../../../core/widgets/product_image.dart';
import '../../cart/models/cart_item.dart';
import 'section_card.dart';

/// The products being ordered, with the merchandise subtotal.
class OrderItemsCard extends StatelessWidget {
  final List<CartItem> items;
  final double subtotal;

  const OrderItemsCard({super.key, required this.items, required this.subtotal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SectionCard(
      icon: Icons.inventory_2_outlined,
      title: 'Products Ordered (${items.length})',
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 20),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ProductImage(items[i].product.imageUrl, width: 56, height: 56),
                ),
                const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[i].variantSelection.isNotEmpty
                              ? '${items[i].product.name} (${items[i].variantSelection})'
                              : items[i].product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₱${items[i].product.priceForVariant(items[i].variantSelection).toStringAsFixed(2)}',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                Text('x${items[i].quantity}',
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ],
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Order Total (${items.length} item${items.length == 1 ? '' : 's'})'),
              Text(
                '₱${subtotal.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}