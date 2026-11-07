/// A way to pay at checkout.
///
/// COD is built in. Every other method comes from the admin dashboard, which
/// saves it under `settings/paymentMethods/{key}` (see settings.js).
class PaymentMethod {
  static const codKey = 'cod';

  /// Display names for the providers the admin can configure.
  static const _knownLabels = {
    'gcash': 'GCash',
    'maya': 'Maya',
    'bpi': 'BPI Bank Transfer',
    'bdo': 'BDO Bank Transfer',
  };

  final String key;

  /// Saved to the order as `paymentMethod`. The admin shows it as-is.
  final String label;
  final String bankName;
  final String accountName;
  final String accountNumber;

  /// QR code as a base64 data URL.
  final String qrImage;

  const PaymentMethod({
    required this.key,
    required this.label,
    this.bankName = '',
    this.accountName = '',
    this.accountNumber = '',
    this.qrImage = '',
  });

  static const cod = PaymentMethod(key: codKey, label: 'COD');

  factory PaymentMethod.fromSettings(String key, Map<dynamic, dynamic> map) {
    return PaymentMethod(
      key: key,
      label: _knownLabels[key] ?? _text(map['providerName'], key.toUpperCase()),
      bankName: _text(map['bankName'], ''),
      accountName: _text(map['accountName'], ''),
      accountNumber: _text(map['accountNumber'], ''),
      qrImage: _text(map['qrImage'], ''),
    );
  }

  /// Online methods need the customer to send money and submit a proof.
  bool get isOnline => key != codKey;

  String get subtitle => isOnline
      ? 'Send your payment, then submit the proof'
      : 'Cash on Delivery - pay when your order arrives';

  /// Saved to the order as `paymentStatus`. `pending_verification` is the
  /// value the admin's "Verify Payments" tab already looks for.
  String get initialPaymentStatus => isOnline ? 'pending_verification' : 'Unpaid';

  /// Shown only when the admin typed a bank name that adds information.
  bool get hasDistinctBankName =>
      bankName.isNotEmpty && bankName.toLowerCase() != key;

  static String _text(Object? value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }
}