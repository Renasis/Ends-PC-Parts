import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../legal/data/legal_documents.dart';
import '../../legal/widgets/legal_document_sheet.dart';
import '../models/order.dart';
import '../models/return_reasons.dart';

/// What the customer fills in when asking for a return.
class ReturnRequestData {
  final String reason;

  /// Optional base64 data URL of a proof photo; empty when none.
  final String imageUrl;

  /// Where the refund should be sent, e.g. 'GCash' or 'Bank Transfer - BPI'.
  final String refundMethod;
  final String accountName;
  final String accountNumber;

  const ReturnRequestData({
    required this.reason,
    required this.imageUrl,
    required this.refundMethod,
    required this.accountName,
    required this.accountNumber,
  });
}

/// Shows the return form: reason, optional proof photo and the account the
/// refund should be sent to. Returns null when cancelled.
///
/// There is no payment gateway, so refunds are sent by the shop by hand.
/// The shop can only do that if it knows which account to pay, which is why
/// the account is asked for here and not left for later.
Future<ReturnRequestData?> confirmReturnOrder(
  BuildContext context,
  Order order,
) {
  return showDialog<ReturnRequestData>(
    context: context,
    builder: (_) => _ReturnRequestDialog(order: order),
  );
}

class _ReturnRequestDialog extends StatefulWidget {
  final Order order;
  const _ReturnRequestDialog({required this.order});

  @override
  State<_ReturnRequestDialog> createState() => _ReturnRequestDialogState();
}

class _ReturnRequestDialogState extends State<_ReturnRequestDialog> {
  static const _bankOption = 'Bank Transfer';
  static const _eWallets = {'gcash', 'maya'};

  final _reason = TextEditingController();
  final _bankName = TextEditingController();
  final _accountName = TextEditingController();
  final _accountNumber = TextEditingController();

  late final List<String> _methods;
  late String _method;

  String? _reasonChoice;
  String? _imageUrl;
  String? _imageError;
  String? _reasonError;
  String? _bankError;
  String? _nameError;
  String? _numberError;

  @override
  void initState() {
    super.initState();
    final original = widget.order.originalOnlineMethod;
    _methods = [
      ?original,
      for (final m in const ['GCash', 'Maya', _bankOption])
        if (m.toLowerCase() != original?.toLowerCase()) m,
    ];
    _method = _methods.first;
    _accountName.text = widget.order.recipientName == 'N/A'
        ? ''
        : widget.order.recipientName;
  }

  @override
  void dispose() {
    _reason.dispose();
    _bankName.dispose();
    _accountName.dispose();
    _accountNumber.dispose();
    super.dispose();
  }

  bool get _isEWallet => _eWallets.contains(_method.toLowerCase());
  bool get _needsBankName => _method == _bankOption;

  String _label(String method) {
    final original = widget.order.originalOnlineMethod;
    return method == original ? '$method (same as your payment)' : method;
  }

  Future<void> _pickImage() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 1600,
        imageQuality: 60,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.length > 700 * 1024) {
        setState(() => _imageError = 'Image too large. Choose a smaller photo.');
      } else {
        setState(() {
          _imageUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
          _imageError = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _imageError = 'Could not load that image.');
    }
  }

  /// Returns an error message, or null when the account number looks valid.
  String? _checkNumber(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return 'Enter the account number.';
    if (_isEWallet) {
      final digits = value.replaceAll(RegExp(r'[\s-]'), '');
      final ok = RegExp(r'^(09\d{9}|\+?639\d{9})$').hasMatch(digits);
      return ok ? null : 'Enter an 11-digit mobile number, e.g. 09171234567.';
    }
    final digits = value.replaceAll(RegExp(r'[\s-]'), '');
    return RegExp(r'^\d{7,20}$').hasMatch(digits)
        ? null
        : 'Enter a valid account number (7 to 20 digits).';
  }

  void _submit() {
    final choice = _reasonChoice;
    final other = _reason.text.trim();
    final reason = choice == ReturnReasons.other ? 'Other: $other' : choice;
    final bank = _bankName.text.trim();
    final name = _accountName.text.trim();
    final number = _accountNumber.text.trim();

    final reasonError = choice == null
        ? 'Please choose a reason.'
        : (choice == ReturnReasons.other && other.isEmpty)
            ? 'Please tell us the reason.'
            : null;
    final bankError =
        _needsBankName && bank.isEmpty ? 'Enter the bank name.' : null;
    final nameError = name.length < 2 ? 'Enter the account holder name.' : null;
    final numberError = _checkNumber(number);

    if (reasonError != null ||
        bankError != null ||
        nameError != null ||
        numberError != null) {
      setState(() {
        _reasonError = reasonError;
        _bankError = bankError;
        _nameError = nameError;
        _numberError = numberError;
      });
      return;
    }

    Navigator.pop(
      context,
      ReturnRequestData(
        reason: reason!,
        imageUrl: _imageUrl ?? '',
        refundMethod: _needsBankName ? '$_bankOption - $bank' : _method,
        accountName: name,
        accountNumber: number,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paidCod = widget.order.originalOnlineMethod == null;

    return AlertDialog(
      title: const Text('Request Return'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => LegalDocumentSheet.show(
                  context,
                  LegalDocuments.returnPolicy,
                ),
                icon: const Icon(Icons.info_outline, size: 18),
                label: const Text('Read our Return & Refund Policy'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Why do you want to return this order?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _reasonChoice,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Reason',
                border: const OutlineInputBorder(),
                errorText: _reasonChoice == ReturnReasons.other
                    ? null
                    : _reasonError,
              ),
              items: [
                for (final r in ReturnReasons.presets)
                  DropdownMenuItem(value: r, child: Text(r)),
              ],
              onChanged: (value) => setState(() {
                _reasonChoice = value;
                _reasonError = null;
              }),
            ),
            if (_reasonChoice == ReturnReasons.other) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _reason,
                onChanged: (_) {
                  if (_reasonError != null) setState(() => _reasonError = null);
                },
                decoration: InputDecoration(
                  labelText: 'Tell us what happened',
                  border: const OutlineInputBorder(),
                  errorText: _reasonError,
                ),
                maxLines: 3,
                maxLength: 480,
              ),
            ],
            const SizedBox(height: 4),
            const Text(
              'Photo of the problem (optional, but helps us approve faster)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (_imageUrl != null) ...[
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      base64Decode(_imageUrl!.substring(_imageUrl!.indexOf(',') + 1)),
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => setState(() => _imageUrl = null),
                    child: const Text('Remove'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.upload_file),
              label: Text(_imageUrl == null ? 'Choose photo' : 'Change photo'),
            ),
            if (_imageError != null) ...[
              const SizedBox(height: 6),
              Text(_imageError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
            const Divider(height: 28),
            const Text(
              'Where should we send your refund?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              paidCod
                  ? 'You paid by cash on delivery, so we will send the refund to an e-wallet or bank account.'
                  : 'We send refunds by hand to the account you enter below, so please double-check it.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _method,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Refund method',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final m in _methods)
                  DropdownMenuItem(value: m, child: Text(_label(m))),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _method = value;
                  _numberError = null;
                  _bankError = null;
                });
              },
            ),
            if (_needsBankName) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _bankName,
                onChanged: (_) {
                  if (_bankError != null) setState(() => _bankError = null);
                },
                decoration: InputDecoration(
                  labelText: 'Bank name',
                  hintText: 'e.g., BPI, BDO',
                  border: const OutlineInputBorder(),
                  errorText: _bankError,
                ),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _accountName,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
              decoration: InputDecoration(
                labelText: 'Account holder name',
                border: const OutlineInputBorder(),
                errorText: _nameError,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _accountNumber,
              keyboardType: TextInputType.number,
              onChanged: (_) {
                if (_numberError != null) setState(() => _numberError = null);
              },
              decoration: InputDecoration(
                labelText: _isEWallet ? 'Mobile number' : 'Account number',
                border: const OutlineInputBorder(),
                errorText: _numberError,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          child: const Text('Submit Return'),
        ),
      ],
    );
  }
}
