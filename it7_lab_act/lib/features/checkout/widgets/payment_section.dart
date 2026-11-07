import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/checkout_provider.dart';
import 'payment_instructions.dart';
import 'payment_picker_sheet.dart';
import 'payment_proof_form.dart';
import 'section_card.dart';

/// Chosen payment method, where to send the money, and the payment proof.
class PaymentSection extends StatelessWidget {
  /// Total the customer must pay.
  final double amount;

  const PaymentSection({super.key, required this.amount});

  @override
  Widget build(BuildContext context) {
    final checkout = context.watch<CheckoutProvider>();
    final method = checkout.selectedMethod;
    final primary = Theme.of(context).colorScheme.primary;

    return SectionCard(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Payment Method',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => showPaymentPicker(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: primary.withValues(alpha: 0.12),
                    child: Icon(paymentMethodIcon(method), color: primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(method.label,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          method.subtitle,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Text('Change', style: TextStyle(color: primary)),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
          if (method.isOnline) ...[
            const SizedBox(height: 12),
            PaymentInstructions(method: method, amount: amount),
            const SizedBox(height: 16),
            const PaymentProofForm(),
          ],
        ],
      ),
    );
  }
}