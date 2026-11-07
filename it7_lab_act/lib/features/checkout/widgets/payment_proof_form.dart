import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/payment_proof.dart';
import '../providers/checkout_provider.dart';

/// After paying, the customer submits a screenshot, or types the reference
/// number with the date and time of the payment.
class PaymentProofForm extends StatefulWidget {
  const PaymentProofForm({super.key});

  @override
  State<PaymentProofForm> createState() => _PaymentProofFormState();
}

class _PaymentProofFormState extends State<PaymentProofForm> {
  late final TextEditingController _referenceController;

  @override
  void initState() {
    super.initState();
    _referenceController = TextEditingController(
      text: context.read<CheckoutProvider>().referenceNumber,
    );
  }

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final checkout = context.read<CheckoutProvider>();
    final now = DateTime.now();
    final earliest = now.subtract(const Duration(days: 30));

    var initial = checkout.paidAt ?? now;
    if (initial.isAfter(now) || initial.isBefore(earliest)) initial = now;

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: earliest,
      lastDate: now,
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;

    checkout.setPaidAt(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final checkout = context.watch<CheckoutProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Payment proof', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<PaymentProofType>(
            segments: const [
              ButtonSegment(
                value: PaymentProofType.screenshot,
                icon: Icon(Icons.image_outlined),
                label: Text('Screenshot'),
              ),
              ButtonSegment(
                value: PaymentProofType.reference,
                icon: Icon(Icons.tag),
                label: Text('Reference no.'),
              ),
            ],
            selected: {checkout.proofType},
            onSelectionChanged: (selection) =>
                checkout.setProofType(selection.first),
          ),
        ),
        const SizedBox(height: 12),
        if (checkout.proofType == PaymentProofType.screenshot)
          _screenshotPicker(checkout)
        else
          _referenceFields(checkout),
        if (checkout.proofError.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            checkout.proofError,
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _screenshotPicker(CheckoutProvider checkout) {
    final image = checkout.screenshot;
    if (image == null) {
      return OutlinedButton.icon(
        onPressed: checkout.pickScreenshot,
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload payment screenshot'),
      );
    }

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            base64Decode(image.substring(image.indexOf(',') + 1)),
            width: 72,
            height: 96,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: checkout.pickScreenshot,
                child: const Text('Change'),
              ),
              TextButton(
                onPressed: checkout.removeScreenshot,
                child: const Text('Remove'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _referenceFields(CheckoutProvider checkout) {
    final paidAt = checkout.paidAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _referenceController,
          onChanged: checkout.setReferenceNumber,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Reference number',
            prefixIcon: Icon(Icons.tag),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pickDateTime,
          icon: const Icon(Icons.schedule),
          label: Text(
            paidAt == null ? 'Select date and time paid' : _formatDateTime(paidAt),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Method used: ${checkout.selectedMethod.label}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  static String _formatDateTime(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final period = d.hour < 12 ? 'AM' : 'PM';
    return '${months[d.month - 1]} ${d.day}, ${d.year} $hour:$minute $period';
  }
}