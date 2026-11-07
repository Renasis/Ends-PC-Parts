import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/product_image.dart';
import '../../products/providers/product_provider.dart';
import '../models/order_item.dart';

/// One line of an order: picture, name, variant, price x quantity and total.
///
/// The picture comes from the product list the app already loaded. If the
/// product was deleted since the order, a placeholder is shown.
class OrderItemTile extends StatelessWidget {
  final OrderItem item;

  const OrderItemTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final image = context.select<ProductProvider, String>(
      (p) => p.findById(item.productId)?.imageUrl ?? '',
    );
    final muted = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ProductImage(image, width: 56, height: 56, iconSize: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (item.variantSelection.isNotEmpty)
                  Text(item.variantSelection, style: muted),
                Text(
                  '₱${item.price.toStringAsFixed(2)} x ${item.quantity}',
                  style: muted,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '₱${item.lineTotal.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
