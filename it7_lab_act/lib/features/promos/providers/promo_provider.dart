import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../models/promo_model.dart';

/// Voucher codes managed by the admin under `promos/{CODE}`:
/// code, discountType ('percentage' or 'fixed'), discountValue, minSpend.
class PromoProvider with ChangeNotifier {
  // Created on first use, so the discount maths can be tested without Firebase.
  late final DatabaseReference _promos =
      FirebaseDatabase.instance.ref('promos');

  Promo? _appliedPromo;
  bool _isLoading = false;
  String _errorMessage = '';

  Promo? get appliedPromo => _appliedPromo;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  /// Looks the code up in the database and applies it when it is valid and
  /// the [subtotal] reaches its minimum spend.
  Future<bool> validateAndApplyPromo(String code, double subtotal) async {
    final key = code.trim().toUpperCase();

    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      // Database keys cannot contain these characters, so such a code can
      // never exist.
      if (key.isEmpty || RegExp(r'[.$#\[\]/]').hasMatch(key)) {
        return _fail('Invalid promo code.');
      }

      // The database rules only allow looking up ONE code by its key (so
      // customers cannot list every voucher). A plain child read is refused,
      // so ask with a query on the key instead.
      final snapshot = await _promos.orderByKey().equalTo(key).get();
      final found = snapshot.value;
      final value = found is Map ? found[key] : null;
      if (value is! Map) return _fail('Invalid promo code.');

      final promo = Promo.fromMap(key, value);
      final isPercentage = promo.discountType == 'percentage';
      final validConfig = promo.discountValue > 0 &&
          (!isPercentage || promo.discountValue <= 100);
      if (!validConfig) return _fail('Invalid promo code.');

      if (subtotal < promo.minSpend) {
        return _fail(
          'Minimum spend of ₱${promo.minSpend.toStringAsFixed(2)} required.',
        );
      }

      _appliedPromo = promo;
      return true;
    } on FirebaseException catch (e) {
      return _fail(
        e.code == 'permission-denied'
            ? 'Please log in to use a promo code.'
            : 'Could not check the promo code. Please check your connection.',
      );
    } catch (_) {
      return _fail('Could not check the promo code. Please try again.');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool _fail(String message) {
    _errorMessage = message;
    return false;
  }

  /// The discount in pesos for [subtotal]. Zero when no promo is applied or
  /// the subtotal fell below the minimum spend (for example after the
  /// customer removed an item).
  double calculateDiscount(double subtotal) {
    final promo = _appliedPromo;
    if (promo == null || subtotal < promo.minSpend) return 0.0;

    final raw = promo.discountType == 'percentage'
        ? subtotal * promo.discountValue / 100
        : promo.discountValue;
    final capped = raw.clamp(0.0, subtotal).toDouble();
    return (capped * 100).roundToDouble() / 100;
  }

  /// For tests only: applies [promo] without looking it up.
  @visibleForTesting
  void applyForTest(Promo promo) {
    _appliedPromo = promo;
    notifyListeners();
  }

  void removePromo() {
    _appliedPromo = null;
    _errorMessage = '';
    notifyListeners();
  }
}
