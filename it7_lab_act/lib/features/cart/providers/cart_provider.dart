import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../products/models/product.dart';
import '../models/cart_item.dart';

/// The shopping cart.
///
/// A guest's cart lives in memory only. A signed-in customer's cart is also
/// saved under `users/{uid}/cart` (productId -> quantity), so it follows the
/// account and never shows up under another account or as a guest.
///
/// Created once in main.dart and re-pointed at the current user with
/// [bindUser] whenever the login state changes. When a guest logs in, the
/// items already in the guest cart are merged into the account's cart.
class CartProvider with ChangeNotifier {
  static const _loadError =
      'Could not load your saved cart. Please check your connection and try again.';
  static const _saveError =
      'Could not save your cart. Please check your connection and try again.';

  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  final Map<String, CartItem> _items = {};
  final Set<String> _selectedIds = {}; // Items ticked for checkout

  String? _userId;
  bool _isLoading = false;

  /// True once the account's saved cart has been read. Nothing is written
  /// before that, so a failed load can never wipe the saved cart.
  bool _loaded = false;
  String _syncError = '';
  bool _disposed = false;

  Map<String, CartItem> get items => {..._items};
  Set<String> get selectedIds => {..._selectedIds};

  /// True while the saved cart of a just-logged-in account is loading.
  bool get isLoading => _isLoading;

  /// Non-empty when the cart could not be loaded or saved.
  String get syncError => _syncError;

  bool isSelected(String productId, {String variantSelection = ''}) =>
      _selectedIds.contains(_cartKey(productId, variantSelection));

  /// The ticked items, in cart order.
  List<CartItem> get selectedItems => _items.entries
      .where((e) => _selectedIds.contains(e.key))
      .map((e) => e.value)
      .toList();

  /// Total number of units in the cart.
  int get itemCount => _items.values.fold(0, (sum, item) => sum + item.quantity);

  /// Number of units in the ticked items.
  int get selectedItemCount =>
      selectedItems.fold(0, (sum, item) => sum + item.quantity);

  /// Total price of the ticked items only.
  double get totalAmount =>
      selectedItems.fold(0.0, (sum, item) => sum + item.totalPrice);

  // ------------------------------------------------------------ account link

  /// Points the cart at [userId], or at the guest cart when null.
  /// Safe to call on every auth change: the same user is a no-op.
  void bindUser(String? userId) {
    if (userId == _userId) return;

    final wasGuest = _userId == null;
    _userId = userId;
    _loaded = false;
    _syncError = '';

    // Guest -> account keeps the guest items so they can be merged in.
    // Logout (or switching accounts) empties the cart.
    if (!wasGuest) {
      _items.clear();
      _selectedIds.clear();
    }

    if (userId != null) {
      _isLoading = true;
      unawaited(_loadFor(userId));
    } else {
      _isLoading = false;
    }

    // Called while the widget tree is building, so notify after the frame.
    scheduleMicrotask(notifyListeners);
  }

  /// Tries again after a failed load or save.
  void retrySync() {
    final userId = _userId;
    if (userId == null) return;

    _syncError = '';
    if (_loaded) {
      unawaited(_save());
    } else {
      _isLoading = true;
      unawaited(_loadFor(userId));
    }
    notifyListeners();
  }

  /// Cart key: productId when no variants, productId|variantLabel otherwise.
  String _cartKey(String productId, String variantSelection) {
    return variantSelection.isNotEmpty ? '$productId|$variantSelection' : productId;
  }

  /// Splits a cart key back into (productId, variantSelection).
  (String, String) _splitCartKey(String key) {
    final idx = key.indexOf('|');
    if (idx == -1) return (key, '');
    return (key.substring(0, idx), key.substring(idx + 1));
  }

  /// Firebase keys cannot contain . / # $ [ ] so the variant part of a cart
  /// key is percent-encoded (and "." too) before it is saved. The cart keeps
  /// using the plain `productId|variantLabel` key in memory.
  String _toDbKey(String cartKey) {
    final (pid, variant) = _splitCartKey(cartKey);
    if (variant.isEmpty) return pid;
    return '$pid|${Uri.encodeComponent(variant).replaceAll('.', '%2E')}';
  }

  /// Reverses [_toDbKey]. A key saved before the encoding existed is not
  /// valid percent-encoding when it holds a "%", so it is kept as it is.
  String _fromDbKey(String dbKey) {
    final (pid, variant) = _splitCartKey(dbKey);
    if (variant.isEmpty) return pid;
    try {
      return '$pid|${Uri.decodeComponent(variant)}';
    } on FormatException {
      return dbKey;
    }
  }

  /// Tells the screens the cart changed and saves it.
  void _changed() {
    notifyListeners();
    unawaited(_save());
  }

  // ---------------------------------------------------------------- selection

  void toggleSelection(String productId, {String variantSelection = ''}) {
    final key = _cartKey(productId, variantSelection);
    if (!_selectedIds.remove(key)) {
      _selectedIds.add(key);
    }
    notifyListeners();
  }

  void toggleSelectAll(bool selectAll) {
    if (selectAll) {
      _selectedIds.addAll(_items.keys);
    } else {
      _selectedIds.clear();
    }
    notifyListeners();
  }

  // ------------------------------------------------------------------ editing

  /// Reads the saved cart, merges in anything added meanwhile (the guest
  /// cart), and rebuilds the items from the live product data.
  Future<void> _loadFor(String userId) async {
    try {
      final saved = await _db.child('users').child(userId).child('cart').get();
      if (_disposed || _userId != userId) return; // logged out / switched

      final savedQuantities = <String, int>{};
      final rawSaved = saved.value;
      if (rawSaved is Map) {
        rawSaved.forEach((key, value) {
          final qty = value is num ? value.toInt() : int.tryParse('$value') ?? 0;
          if (qty > 0) savedQuantities[_fromDbKey(key.toString())] = qty;
        });
      }

      // Download only the products that are in the cart, not the whole shop.
      final fetchIds = <String>{};
      for (final savedKey in savedQuantities.keys) {
        final (pid, _) = _splitCartKey(savedKey);
        fetchIds.add(pid);
      }
      fetchIds.addAll(_items.keys.map((k) => _splitCartKey(k).$1));
      final fetchIdList = fetchIds.toList();

      final snapshots = await Future.wait(
        fetchIdList.map((id) => _db.child('products').child(id).get()),
      );
      if (_disposed || _userId != userId) return;

      final latest = <String, Product>{};
      for (var i = 0; i < fetchIdList.length; i++) {
        final value = snapshots[i].value;
        if (value is Map) {
          latest[fetchIdList[i]] = Product.fromMap(fetchIdList[i], value);
        }
      }

      // Items added before the saved cart arrived (the guest cart), including
      // any added while the products were downloading.
      final quantities = Map<String, int>.of(savedQuantities);
      var hadLocalItems = false;
      for (final entry in _items.entries) {
        hadLocalItems = true;
        quantities[entry.key] = (quantities[entry.key] ?? 0) + entry.value.quantity;
        final (pid, _) = _splitCartKey(entry.key);
        if (!fetchIdList.contains(pid)) {
          latest[pid] = entry.value.product;
        }
      }

      // Deleted or out-of-stock products are dropped; quantities are capped
      // at the available stock.
      _items.clear();
      _selectedIds.clear();
      for (final entry in quantities.entries) {
        final (pid, variant) = _splitCartKey(entry.key);
        final product = latest[pid];
        if (product == null) continue;
        final effectiveStock = product.stockForVariant(variant);
        if (effectiveStock <= 0) continue;
        final qty = entry.value > effectiveStock ? effectiveStock : entry.value;
        _items[entry.key] =
            CartItem(product: product, quantity: qty, variantSelection: variant);
        _selectedIds.add(entry.key);
      }

      _loaded = true;
      _isLoading = false;
      notifyListeners();

      final rebuilt = {for (final e in _items.entries) e.key: e.value.quantity};
      if (hadLocalItems || !mapEquals(savedQuantities, rebuilt)) {
        await _save();
      }
    } catch (e) {
      debugPrint('CartProvider: $e');
      if (_disposed || _userId != userId) return;
      _syncError = _loadError;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Saves the cart under the signed-in account. Guests are not saved.
  Future<void> _save() async {
    final userId = _userId;
    if (userId == null || !_loaded) return;

    final ref = _db.child('users').child(userId).child('cart');
    try {
      if (_items.isEmpty) {
        await ref.remove();
      } else {
        await ref.set({
          for (final e in _items.entries) _toDbKey(e.key): e.value.quantity,
        });
      }
      if (_syncError.isNotEmpty && _userId == userId) {
        _syncError = '';
        notifyListeners();
      }
    } catch (e) {
      debugPrint('CartProvider: save failed: $e');
      if (_userId != userId) return;
      _syncError = _saveError;
      notifyListeners();
    }
  }

  /// Adds [quantity] units of [product] with [variantSelection] to the cart.
  ///
  /// Returns a user-facing message when the stock cannot cover the request
  /// (nothing is added), or null on success.
  String? addItem(Product product,
      {int quantity = 1, String variantSelection = ''}) {
    final effectiveStock = product.stockForVariant(variantSelection);
    if (effectiveStock <= 0) {
      return 'This product is out of stock.';
    }

    final cartKey = _cartKey(product.id, variantSelection);
    final inCart = _items[cartKey]?.quantity ?? 0;
    final remaining = effectiveStock - inCart;
    if (quantity > remaining) {
      return remaining <= 0
          ? 'All $effectiveStock available are already in your cart.'
          : 'Only $effectiveStock in stock. You can add $remaining more.';
    }

    // Replace the stored product so the cart keeps the latest price and stock.
    _items[cartKey] = CartItem(
      product: product,
      quantity: inCart + quantity,
      variantSelection: variantSelection,
    );
    if (inCart == 0) {
      _selectedIds.add(cartKey); // auto-tick newly added items
    }
    _changed();
    return null;
  }

  /// Updates the cart with fresh product data after checkout found changes.
  ///
  /// Only the items in [checkedKeys] are touched. Products missing from
  /// [latest] (deleted) or out of stock are removed, and quantities are
  /// reduced to the available stock.
  void syncWithLatest({
    required Iterable<String> checkedKeys,
    required Map<String, Product> latest,
  }) {
    for (final cartKey in checkedKeys) {
      final item = _items[cartKey];
      if (item == null) continue;

      final (pid, _) = _splitCartKey(cartKey);
      final fresh = latest[pid];
      if (fresh == null || fresh.stockForVariant(item.variantSelection) <= 0) {
        _items.remove(cartKey);
        _selectedIds.remove(cartKey);
        continue;
      }

      final quantity =
          item.quantity > fresh.stockForVariant(item.variantSelection)
              ? fresh.stockForVariant(item.variantSelection)
              : item.quantity;
      _items[cartKey] = CartItem(
        product: fresh,
        quantity: quantity,
        variantSelection: item.variantSelection,
      );
    }
    _changed();
  }

  /// Removes one unit; removes the item when it was the last one.
  void removeSingleItem(String productId, {String variantSelection = ''}) {
    final key = _cartKey(productId, variantSelection);
    final item = _items[key];
    if (item == null) return;

    if (item.quantity > 1) {
      item.quantity--;
    } else {
      _items.remove(key);
      _selectedIds.remove(key);
    }
    _changed();
  }

  void removeItem(String productId, {String variantSelection = ''}) {
    final key = _cartKey(productId, variantSelection);
    _items.remove(key);
    _selectedIds.remove(key);
    _changed();
  }

  void removeSelected() {
    _items.removeWhere((key, _) => _selectedIds.contains(key));
    _selectedIds.clear();
    _changed();
  }

  void clearCart() {
    _items.clear();
    _selectedIds.clear();
    _changed();
  }

  // ---------------------------------------------------------------- lifecycle

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