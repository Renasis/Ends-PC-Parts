import 'dart:convert';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../cart/models/cart_item.dart';
import '../../cart/providers/cart_provider.dart';
import '../models/checkout_settings.dart';
import '../models/payment_method.dart';
import '../models/payment_proof.dart';
import '../services/checkout_service.dart';

/// State and rules for one checkout session: settings from the admin, the
/// chosen payment method and proof, the final stock/price check, and saving
/// the order.
class CheckoutProvider with ChangeNotifier {
  /// Resized screenshots larger than this are rejected (keeps the database small).
  static const _maxProofBytes = 700 * 1024;

  /// The database rules accept at most this many different products per order.
  static const maxOrderLines = 25;

  final CheckoutService _service;
  final ImagePicker _picker;
  final CartProvider _cart;
  final bool _isBuyNow;

  List<CartItem> _items;
  bool _disposed = false;

  bool _isLoadingSettings = true;
  String _settingsError = '';
  CheckoutSettings? _settings;
  List<PaymentMethod> _methods = const [PaymentMethod.cod];
  PaymentMethod _selectedMethod = PaymentMethod.cod;

  PaymentProofType _proofType = PaymentProofType.screenshot;
  String? _screenshot;
  String _referenceNumber = '';
  DateTime? _paidAt;
  String _proofError = '';

  bool _isSubmitting = false;
  String _notice = '';
  String _errorMessage = '';

  CheckoutProvider({
    required List<CartItem> items,
    required this._cart,
    required this._isBuyNow,
    CheckoutService? service,
    ImagePicker? picker,
  })  : _items = List.of(items),
        _service = service ?? CheckoutService(),
        _picker = picker ?? ImagePicker() {
    loadSettings();
  }

  // ------------------------------------------------------------------ state

  List<CartItem> get items => List.unmodifiable(_items);
  bool get isLoadingSettings => _isLoadingSettings;

  /// Non-empty when the shipping fee and payment methods could not be loaded.
  String get settingsError => _settingsError;

  /// What delivery to [province] costs for the current items (0 when the
  /// order earns free shipping).
  double shippingFeeFor(String province) =>
      _settings?.feeFor(province, subtotal) ?? 0;

  /// True when the shipping fee is waived by the free-shipping minimum.
  bool isFreeShipping() => _settings?.qualifiesForFree(subtotal) ?? false;

  /// The standard fee for [province] before any free-shipping offer.
  double regularShippingFeeFor(String province) =>
      _settings?.regularFeeFor(province) ?? 0;

  /// How much more to add for free shipping; null when there is no offer or
  /// it is already earned.
  double? get remainingForFreeShipping =>
      _settings?.remainingForFree(subtotal);
  List<PaymentMethod> get methods => _methods;
  PaymentMethod get selectedMethod => _selectedMethod;

  PaymentProofType get proofType => _proofType;
  String? get screenshot => _screenshot;
  String get referenceNumber => _referenceNumber;
  DateTime? get paidAt => _paidAt;
  String get proofError => _proofError;

  bool get isSubmitting => _isSubmitting;

  /// Explains what changed when the final check updated the order.
  String get notice => _notice;

  /// Last error from placing the order, ready to show to the customer.
  String get errorMessage => _errorMessage;

  double get subtotal =>
      _items.fold(0.0, (sum, item) => sum + item.totalPrice);

  double grandTotal(double discount, String province) =>
      subtotal - discount + shippingFeeFor(province);

  // --------------------------------------------------------------- settings

  Future<void> loadSettings() async {
    _isLoadingSettings = true;
    _settingsError = '';
    notifyListeners();

    try {
      final settings = await _service.loadSettings();
      _settings = settings;
      _methods = settings.paymentMethods;
      _selectedMethod = _methods.firstWhere(
        (m) => m.key == _selectedMethod.key,
        orElse: () => PaymentMethod.cod,
      );
    } catch (e) {
      debugPrint('CheckoutProvider: $e');
      _settingsError =
          'Could not load the shipping fee and payment methods. Please check your connection and try again.';
    }

    _isLoadingSettings = false;
    notifyListeners();
  }

  // ---------------------------------------------------------- payment proof

  void selectMethod(PaymentMethod method) {
    _selectedMethod = method;
    _proofError = '';
    notifyListeners();
  }

  void setProofType(PaymentProofType type) {
    _proofType = type;
    _proofError = '';
    notifyListeners();
  }

  void setReferenceNumber(String value) {
    _referenceNumber = value;
    if (_proofError.isNotEmpty) {
      _proofError = '';
      notifyListeners();
    }
  }

  void setPaidAt(DateTime value) {
    _paidAt = value;
    _proofError = '';
    notifyListeners();
  }

  /// Lets the customer pick a screenshot, shrinks it, and keeps it as base64.
  Future<void> pickScreenshot() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 720,
        maxHeight: 1600,
        imageQuality: 60,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (bytes.length > _maxProofBytes) {
        _proofError =
            'That image is too large. Please crop it or choose a smaller screenshot.';
      } else {
        _screenshot = 'data:${_mimeType(bytes)};base64,${base64Encode(bytes)}';
        _proofError = '';
      }
    } catch (e) {
      debugPrint('CheckoutProvider: $e');
      _proofError = 'Could not load that image. Please try another one.';
    }
    notifyListeners();
  }

  void removeScreenshot() {
    _screenshot = null;
    notifyListeners();
  }

  static String _mimeType(Uint8List bytes) {
    final isPng = bytes.length > 4 && bytes[0] == 0x89 && bytes[1] == 0x50;
    return isPng ? 'image/png' : 'image/jpeg';
  }

  /// Returns the proof to save, or null when COD is chosen or the proof is
  /// not complete (in which case [proofError] explains why).
  PaymentProof? _buildProof() {
    if (!_selectedMethod.isOnline) return null;

    if (_proofType == PaymentProofType.screenshot) {
      final image = _screenshot;
      if (image == null) {
        _proofError = 'Please upload a screenshot of your payment.';
        return null;
      }
      return PaymentProof.screenshot(image);
    }

    final reference = _referenceNumber.trim();
    final paidAt = _paidAt;
    if (reference.length < 4) {
      _proofError = 'Enter the reference number from your payment.';
      return null;
    }
    if (paidAt == null) {
      _proofError = 'Select the date and time you paid.';
      return null;
    }
    if (paidAt.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      _proofError = 'The payment date and time cannot be in the future.';
      return null;
    }
    return PaymentProof.reference(referenceNumber: reference, paidAt: paidAt);
  }

  // ------------------------------------------------------------- place order

  /// Places the order. Returns the order id, or null when it was not placed.
  /// In that case [errorMessage], [proofError] or [notice] explains why.
  Future<String?> placeOrder({
    required String? userId,
    required String recipientName,
    required String phoneNumber,
    required String deliveryAddress,
    required String province,
    double? deliveryLat,
    double? deliveryLng,
    required double discount,
    required String? promoCode,
  }) async {
    _errorMessage = '';
    _notice = '';
    _proofError = '';

    if (userId == null) {
      _errorMessage = 'Please log in to place your order.';
      notifyListeners();
      return null;
    }
    if (_items.isEmpty) {
      _errorMessage = 'No items selected for checkout.';
      notifyListeners();
      return null;
    }

    if (_items.length > maxOrderLines) {
      _errorMessage =
          'An order can have up to $maxOrderLines different products. '
          'Please remove some items or place two orders.';
      notifyListeners();
      return null;
    }

    final proof = _buildProof();
    if (_selectedMethod.isOnline && proof == null) {
      notifyListeners();
      return null;
    }

    _isSubmitting = true;
    notifyListeners();

    try {
      // Final stock and price check against the live products.
      final check = await _service.checkItems(_items);
      if (check.changed) {
        if (!_isBuyNow) {
          _cart.syncWithLatest(
            checkedKeys: _items.map((i) => i.product.id + (i.variantSelection.isEmpty ? '' : '|${i.variantSelection}')),
            latest: check.latest,
          );
        }
        _items = check.items;
        _notice = '${check.messages.join('\n')}\n'
            'Please review your order, then place it again.';
        _isSubmitting = false;
        notifyListeners();
        return null;
      }

      final order = <String, Object?>{
        'userId': userId,
        'recipientName': recipientName,
        'phoneNumber': phoneNumber,
        'deliveryAddress': deliveryAddress,
        if (deliveryLat != null && deliveryLng != null) ...{
          'deliveryLat': deliveryLat,
          'deliveryLng': deliveryLng,
        },
        'paymentMethod': _selectedMethod.label,
        'paymentStatus': _selectedMethod.initialPaymentStatus,
        'items': _items
            .map((item) => {
                  'productId': item.product.id,
                  'productName': item.product.name,
                  'quantity': item.quantity,
                  'price': item.product.priceForVariant(item.variantSelection),
                  'variantSelection': item.variantSelection,
                })
            .toList(),
        'subtotal': subtotal,
        'discount': discount,
        'promoCode': promoCode,
        'shippingFee': shippingFeeFor(province),
        // The database rules use this to check the fee against the admin's
        // province fees. Empty when the province is unknown (standard fee).
        'shippingProvince': CheckoutSettings.provinceKey(province),
        'grandTotal': grandTotal(discount, province),
        'status': 'Pending',
        'createdAt': ServerValue.timestamp,
        // The database rules require these on every new order:
        // `cancellationReason` must exist as a string, and `returnedAt` must
        // start at 0 so the customer can request a return later.
        'cancellationReason': '',
        'returnedAt': 0,
        ...?proof?.toOrderFields(),
      };

      final orderId = await _service.placeOrder(
        order,
        proofImage: proof?.imageDataUrl,
      );
      if (!_isBuyNow) {
        _cart.removeSelected(); // only the purchased items, not the whole cart
      }
      _isSubmitting = false;
      notifyListeners();
      return orderId;
    } on OrderTermsChangedException catch (e) {
      _notice = e.message;
      await loadSettings(); // show the new shipping fee
    } on FirebaseException catch (e) {
      debugPrint('CheckoutProvider: ${e.code} ${e.message}');
      _errorMessage = e.code == 'permission-denied'
          ? 'We could not place this order. A price, stock level or voucher '
              'may have just changed, or your login expired. Please review '
              'your cart and try again.'
          : 'Could not place your order. Please check your connection and try again.';
    } catch (e) {
      debugPrint('CheckoutProvider: $e');
      _errorMessage =
          'Could not place your order. Please check your connection and try again.';
    }

    _isSubmitting = false;
    notifyListeners();
    return null;
  }

  // -------------------------------------------------------------- lifecycle

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}