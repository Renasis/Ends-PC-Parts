import 'package:flutter/material.dart';

import 'section_card.dart';

/// Subtotal, shipping, voucher discount and the total to pay.
class PriceSummaryCard extends StatelessWidget {
  final double subtotal;
  final double shippingFee;

  /// The fee before the free-shipping offer, shown crossed out when waived.
  final double regularShippingFee;

  /// How much more to add for free shipping; null when there is no offer to
  /// chase (none set, or already earned).
  final double? remainingForFree;
  final double discount;
  final double total;

  const PriceSummaryCard({
    super.key,
    required this.subtotal,
    required this.shippingFee,
    this.regularShippingFee = 0,
    this.remainingForFree,
    required this.discount,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.receipt_long_outlined,
      title: 'Payment Details',
      child: Column(
        children: [
          _line('Merchandise Subtotal', '₱${subtotal.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          _shippingLine(context),
          if (remainingForFree != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Add ₱${remainingForFree!.toStringAsFixed(2)} more to get '
                'free shipping.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
          if (discount > 0) ...[
            const SizedBox(height: 8),
            _line(
              'Voucher Discount',
              '-₱${discount.toStringAsFixed(2)}',
              valueColor: Colors.green.shade700,
            ),
          ],
          const Divider(height: 24),
          _line(
            'Total Payment',
            '₱${total.toStringAsFixed(2)}',
            bold: true,
            valueColor: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }

  /// Shows "FREE" with the usual fee crossed out when shipping is waived.
  Widget _shippingLine(BuildContext context) {
    final waived = shippingFee == 0 && regularShippingFee > 0;
    if (!waived) {
      return _line('Shipping Fee', '₱${shippingFee.toStringAsFixed(2)}');
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Shipping Fee', style: TextStyle(fontSize: 14)),
        Row(
          children: [
            Text(
              '₱${regularShippingFee.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 13,
                decoration: TextDecoration.lineThrough,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'FREE',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _line(String label, String value, {bool bold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            fontSize: bold ? 16 : 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            fontSize: bold ? 18 : 14,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}