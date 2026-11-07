import 'package:flutter/material.dart';

/// "Quantity [-] 1 [+]". The plus button stops at [max] (the stock).
/// A small note under the label shows the limit, or how many of this product
/// are already in the cart.
class QuantitySelector extends StatelessWidget {
  final int quantity;
  final int max;
  final int inCart;
  final ValueChanged<int> onChanged;

  const QuantitySelector({
    super.key,
    required this.quantity,
    required this.max,
    required this.onChanged,
    this.inCart = 0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final note = inCart > 0 ? '$inCart already in your cart' : 'Max $max';

    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quantity',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              note,
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ],
        ),
        const Spacer(),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Decrease quantity',
                icon: const Icon(Icons.remove, size: 18),
                onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
              ),
              SizedBox(
                width: 28,
                child: Text(
                  '$quantity',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: 'Increase quantity',
                icon: const Icon(Icons.add, size: 18),
                onPressed: quantity < max ? () => onChanged(quantity + 1) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
