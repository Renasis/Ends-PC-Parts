import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../promos/providers/promo_provider.dart';

/// Bottom sheet to enter, apply or remove a voucher code.
class VoucherSheet extends StatefulWidget {
  final double subtotal;

  const VoucherSheet({super.key, required this.subtotal});

  @override
  State<VoucherSheet> createState() => _VoucherSheetState();
}

class _VoucherSheetState extends State<VoucherSheet> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    final promo = context.read<PromoProvider>();
    final ok = await promo.validateAndApplyPromo(code, widget.subtotal);
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final promo = context.watch<PromoProvider>();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Voucher',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (promo.appliedPromo != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: Text(promo.appliedPromo!.code),
              subtitle: const Text('Voucher applied'),
              trailing: TextButton(
                onPressed: promo.removePromo,
                child: const Text('Remove'),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(hintText: 'Enter voucher code'),
                  onSubmitted: (_) => _apply(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: promo.isLoading ? null : _apply,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(90, 48)),
                  child: promo.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Apply'),
                ),
              ),
            ],
          ),
          if (promo.errorMessage.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              promo.errorMessage,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}