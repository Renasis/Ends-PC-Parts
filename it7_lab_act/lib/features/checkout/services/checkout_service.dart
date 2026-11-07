import 'dart:math';

import 'package:firebase_database/firebase_database.dart';

import '../../cart/models/cart_item.dart';
import '../../products/models/product.dart';
import '../models/checkout_settings.dart';
import '../models/order_check_result.dart';

/// Thrown when the admin changed something the order depends on (the
/// shipping fee or the voucher) after the customer opened checkout.
class OrderTermsChangedException implements Exception {
  final String message;
  OrderTermsChangedException(this.message);

  @override
  String toString() => 'OrderTermsChangedException($message)';
}

/// All database access for checkout: settings, the final stock and price
/// check, and saving the order under `transactions`.
class CheckoutService {
  final DatabaseReference _root;

  CheckoutService({DatabaseReference? root})
      : _root = root ?? FirebaseDatabase.instance.ref();

  Future<CheckoutSettings> loadSettings() async {
    final snapshot = await _root.child('settings').get();
    final value = snapshot.value;
    return CheckoutSettings.fromMap(
      value is Map ? value : const <dynamic, dynamic>{},
    );
  }

  /// Compares every item with the live product so the customer never pays
  /// for a price or quantity that is no longer true.
  Future<OrderCheckResult> checkItems(List<CartItem> items) async {
    final snapshots = await Future.wait(
      items.map((item) => _root.child('products').child(item.product.id).get()),
    );

    final fresh = <CartItem>[];
    final latest = <String, Product>{};
    final messages = <String>[];

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final name = item.product.name;
      final value = snapshots[i].value;

      if (value is! Map) {
        messages.add('"$name" is no longer available and was removed.');
        continue;
      }

      final product = Product.fromMap(item.product.id, value);
      latest[product.id] = product;

      // The database rules compare the order with the RAW price and stock
      // saved on the product, so a product that cannot pass them would be
      // refused with a vague "permission denied". Say what is wrong instead.
      final rawPrice = value['productPrice'];
      final rawStock = value['productStock'];
      if (rawPrice is! num || rawStock is! num) {
        messages.add(
          '"$name" has a price or stock that is not saved as a number, so it '
          'cannot be ordered yet. Please tell the store.',
        );
        continue;
      }
      if (rawStock <= 0) {
        messages.add(
          '"$name" has no main stock left, so it cannot be ordered right now.',
        );
        continue;
      }
      if ((product.priceForVariant(item.variantSelection) - rawPrice).abs() >
          0.005) {
        messages.add(
          'The selected option of "$name" has a different price than the '
          'listed price, which the store cannot accept yet. Please tell the store.',
        );
        continue;
      }

      final variantStock = min(
        product.stockForVariant(item.variantSelection),
        rawStock.toInt(),
      );
      if (variantStock <= 0) {
        messages.add('"$name" (${item.variantSelection}) is out of stock and was removed.');
        continue;
      }

      final quantity = min(item.quantity, variantStock);
      if (quantity < item.quantity) {
        messages.add(
          'Only $variantStock of "$name" (${item.variantSelection}) left. Quantity reduced to $quantity.',
        );
      }
      final effectivePrice = product.priceForVariant(item.variantSelection);
      if ((effectivePrice - item.product.priceForVariant(item.variantSelection)).abs() > 0.001) {
        messages.add(
          'Price of "$name" changed from ₱${item.product.priceForVariant(item.variantSelection).toStringAsFixed(2)} '
          'to ₱${effectivePrice.toStringAsFixed(2)}.',
        );
      }
      fresh.add(CartItem(
        product: product,
        quantity: quantity,
        variantSelection: item.variantSelection,
      ));
    }

    return OrderCheckResult(items: fresh, latest: latest, messages: messages);
  }

  /// Saves the order and returns its id.
  ///
  /// Stock is not taken here. The app only checks it ([checkItems]); the admin
  /// dashboard deducts it when the order moves to Processing, and refuses if
  /// there is not enough left.
  ///
  /// A payment screenshot ([proofImage]) goes to `paymentProofs/{id}` in the
  /// same write, so the order stays small and the screenshot is only
  /// downloaded when the admin opens it.
  Future<String> placeOrder(
    Map<String, Object?> order, {
    String? proofImage,
  }) async {
    final id = _root.child('transactions').push().key;
    if (id == null) throw StateError('Could not create an order id.');

    // Check the fee and voucher first: the database rules reject an order
    // with outdated terms.
    await _verifyTerms(order);

    final updates = <String, dynamic>{};
    updates['transactions/$id'] = order;
    if (proofImage != null) {
      updates['paymentProofs/$id'] = proofImage;
    }
    await _root.update(updates);
    return id;
  }

  /// Makes sure the shipping fee and voucher in [order] still match what the
  /// admin has set. Throws [OrderTermsChangedException] when they do not.
  Future<void> _verifyTerms(Map<String, Object?> order) async {
    final settings = await loadSettings();
    final fee = (order['shippingFee'] as num?)?.toDouble() ?? 0;
    final orderSubtotal = (order['subtotal'] as num?)?.toDouble() ?? 0;
    // The province was saved as a key (see CheckoutSettings.provinceKey),
    // which maps to the same fee as the province name itself.
    final expected = settings.feeFor(
      order['shippingProvince'] as String? ?? '',
      orderSubtotal,
    );
    if ((expected - fee).abs() > 0.001) {
      throw OrderTermsChangedException(
        'The shipping fee was updated to '
        '₱${expected.toStringAsFixed(2)}. '
        'Please review your order, then place it again.',
      );
    }

    final code = order['promoCode'] as String?;
    if (code == null) return;

    final subtotal = (order['subtotal'] as num?)?.toDouble() ?? 0;
    final discount = (order['discount'] as num?)?.toDouble() ?? 0;
    // Same key query the voucher screen uses; the rules refuse a plain read.
    final found =
        (await _root.child('promos').orderByKey().equalTo(code).get()).value;
    final value = found is Map ? found[code] : null;
    final promo = value is Map ? value : null;

    final minSpend = (promo?['minSpend'] as num?)?.toDouble() ?? 0;
    final amount = (promo?['discountValue'] as num?)?.toDouble() ?? 0;
    final allowed = promo?['discountType'] == 'percentage'
        ? subtotal * amount / 100
        : amount;

    if (promo == null || subtotal < minSpend || discount > allowed + 0.01) {
      throw OrderTermsChangedException(
        'The voucher "$code" is no longer valid. '
        'Remove it, then place your order again.',
      );
    }
  }
}