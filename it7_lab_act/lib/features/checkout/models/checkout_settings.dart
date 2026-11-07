import 'payment_method.dart';

/// What the admin controls for checkout, read from `settings`:
///
/// * `shippingFee`      the standard fee, used when no province fee matches
/// * `provinceFees`     `{key: {name, fee}}`, a different fee for a province
/// * `freeShippingMin`  merchandise subtotal that makes shipping free (0 = off)
/// * `paymentMethods`   the payment methods (COD is built in)
///
/// The database rules recompute the fee from the same three values, so
/// [feeFor] must stay in step with `database.rules.json`.
class CheckoutSettings {
  /// Allowed difference when comparing the subtotal with the free-shipping
  /// minimum. Matches the rules, and absorbs floating-point noise like
  /// 1999.9999999999998.
  static const _tolerance = 0.005;

  /// The standard fee, used outside the provinces in [provinceFees].
  final double shippingFee;

  /// Province key (see [provinceKey]) -> fee for that province.
  final Map<String, double> provinceFees;

  /// 0 means there is no free-shipping offer.
  final double freeShippingMin;

  /// COD first, then the methods the admin configured.
  final List<PaymentMethod> paymentMethods;

  const CheckoutSettings({
    required this.shippingFee,
    this.provinceFees = const {},
    this.freeShippingMin = 0,
    required this.paymentMethods,
  });

  factory CheckoutSettings.fromMap(Map<dynamic, dynamic> map) {
    final methods = <PaymentMethod>[PaymentMethod.cod];

    final raw = map['paymentMethods'];
    if (raw is Map) {
      final keys = raw.keys.map((k) => k.toString()).toList()..sort();
      for (final key in keys) {
        final value = raw[key];
        if (value is Map) {
          methods.add(PaymentMethod.fromSettings(key, value));
        }
      }
    }

    final fees = <String, double>{};
    final rawFees = map['provinceFees'];
    if (rawFees is Map) {
      rawFees.forEach((key, value) {
        // A negative fee is ignored, like the database rules do.
        final fee = value is Map ? value['fee'] : null;
        if (fee is num && fee >= 0) fees[key.toString()] = fee.toDouble();
      });
    }

    return CheckoutSettings(
      shippingFee: _fee(map['shippingFee']),
      provinceFees: fees,
      freeShippingMin: _fee(map['freeShippingMin']),
      paymentMethods: methods,
    );
  }

  /// Turns a province name into the key used in `provinceFees` and saved on
  /// the order as `shippingProvince`. Same spelling rules as the dashboard:
  /// "Rizal", " rizal " and "RIZAL." all become `rizal`.
  static String provinceKey(String province) => province
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  /// The fee before the free-shipping offer: the province's own fee when the
  /// admin set one, otherwise the standard fee.
  double regularFeeFor(String province) {
    final key = provinceKey(province);
    return key.isEmpty ? shippingFee : provinceFees[key] ?? shippingFee;
  }

  /// True when [subtotal] (before any voucher) earns free shipping.
  bool qualifiesForFree(double subtotal) =>
      freeShippingMin > 0 && subtotal + _tolerance >= freeShippingMin;

  /// What the customer pays for delivery to [province] on a [subtotal] order.
  double feeFor(String province, double subtotal) =>
      qualifiesForFree(subtotal) ? 0 : regularFeeFor(province);

  /// How much more the customer must add for free shipping, or null when
  /// there is no offer or it is already earned.
  double? remainingForFree(double subtotal) {
    if (freeShippingMin <= 0 || qualifiesForFree(subtotal)) return null;
    return freeShippingMin - subtotal;
  }

  /// A missing or invalid fee means free shipping, never a negative number.
  static double _fee(Object? value) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString().trim() ?? '') ?? 0;
    return number < 0 ? 0 : number;
  }
}
