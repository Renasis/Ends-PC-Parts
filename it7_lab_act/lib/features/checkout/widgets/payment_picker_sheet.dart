import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/payment_method.dart';
import '../providers/checkout_provider.dart';

/// Lets the customer choose between COD and the methods the admin set up.
Future<void> showPaymentPicker(BuildContext context) async {
  final checkout = context.read<CheckoutProvider>();

  final picked = await showModalBottomSheet<PaymentMethod>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Payment Method',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            for (final method in checkout.methods)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.12),
                  child: Icon(
                    paymentMethodIcon(method),
                    color: Theme.of(ctx).colorScheme.primary,
                  ),
                ),
                title: Text(method.label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(method.subtitle, style: const TextStyle(fontSize: 12)),
                trailing: Icon(
                  method.key == checkout.selectedMethod.key
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: method.key == checkout.selectedMethod.key
                      ? Theme.of(ctx).colorScheme.primary
                      : Colors.grey,
                ),
                onTap: () => Navigator.pop(ctx, method),
              ),
          ],
        ),
      ),
    ),
  );

  if (picked != null) checkout.selectMethod(picked);
}

IconData paymentMethodIcon(PaymentMethod method) => method.isOnline
    ? Icons.account_balance_wallet_outlined
    : Icons.payments_outlined;