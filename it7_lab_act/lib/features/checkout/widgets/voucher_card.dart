import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../promos/providers/promo_provider.dart';
import 'section_card.dart';
import 'voucher_sheet.dart';

/// Shows the applied voucher and opens the voucher sheet.
class VoucherCard extends StatelessWidget {
  final double subtotal;
  final double discount;

  const VoucherCard({super.key, required this.subtotal, required this.discount});

  @override
  Widget build(BuildContext context) {
    final applied = context.watch<PromoProvider>().appliedPromo;

    return SectionCard(
      icon: Icons.local_offer_outlined,
      title: 'Voucher',
      child: InkWell(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => VoucherSheet(subtotal: subtotal),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  applied != null
                      ? '${applied.code}  (-₱${discount.toStringAsFixed(2)})'
                      : 'Select or enter a voucher code',
                  style: TextStyle(
                    color: applied != null ? Colors.green.shade700 : Colors.grey.shade700,
                    fontWeight: applied != null ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}