import 'package:flutter/material.dart';

/// Total and the Place Order button, pinned to the bottom of the screen.
class CheckoutBottomBar extends StatelessWidget {
  final double total;
  final bool isSubmitting;
  final bool enabled;
  final VoidCallback onPlaceOrder;

  const CheckoutBottomBar({
    super.key,
    required this.total,
    required this.isSubmitting,
    required this.enabled,
    required this.onPlaceOrder,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Payment',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(
                    '₱${total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 160,
              height: 48,
              child: ElevatedButton(
                onPressed: isSubmitting || !enabled ? null : onPlaceOrder,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(160, 48),
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                ),
                child: isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Place Order',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}