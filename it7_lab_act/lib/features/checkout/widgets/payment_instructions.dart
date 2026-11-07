import 'package:flutter/material.dart';

import '../../../core/widgets/product_image.dart';
import '../models/payment_method.dart';

/// Where to send the money: the admin's account name, number and QR code.
class PaymentInstructions extends StatelessWidget {
  final PaymentMethod method;
  final double amount;

  const PaymentInstructions({super.key, required this.method, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Send ₱${amount.toStringAsFixed(2)} to:',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (method.hasDistinctBankName) _row('Bank', method.bankName),
          if (method.accountName.isNotEmpty) _row('Account name', method.accountName),
          if (method.accountNumber.isNotEmpty) _row('Number', method.accountNumber),
          if (method.qrImage.isNotEmpty) ...[
            const SizedBox(height: 10),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ProductImage(
                  method.qrImage,
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                  iconSize: 40,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(label, style: const TextStyle(color: Colors.grey)),
            ),
            Expanded(
              child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}