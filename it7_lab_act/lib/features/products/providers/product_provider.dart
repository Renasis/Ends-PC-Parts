import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/product.dart';

/// The order of the product grid in the Shop tab.
enum ProductSort {
  featured('Featured'),
  priceLow('Price: low to high'),
  priceHigh('Price: high to low'),
  nameAZ('Name: A to Z');

  final String label;
  const ProductSort(this.label);
}

class ProductProvider with ChangeNotifier {
  List<Product> _products = [];
  bool _isLoading = false;
  String _errorMessage = '';
  StreamSubscription<DatabaseEvent>? _productsSub;

  /// Without internet the database never answers and never reports an error,
  /// so after this long we show the "could not load" message instead of a
  /// spinner. If the connection comes back, the products appear by themselves.
  static const _loadTimeout = Duration(seconds: 5);
  static const _loadError =
      'Could not load products. Please check your connection and try again.';
  Timer? _loadTimer;

  /// The "no category selected" chip.
  static const allCategories = 'All';

  String _searchQuery = '';
  String _selectedCategory = allCategories;

  /// Price range chosen in the filter sheet. Null means "no limit".
  double? _minPrice;
  double? _maxPrice;
  bool _inStockOnly = false;
  ProductSort _sort = ProductSort.featured;

  List<Product> get products => _products;
  bool get isLoading => _isLoading;

  String get searchQuery => _searchQuery;

  /// Categories come from the products themselves (set by the admin).
  List<String> get categories => [
        allCategories,
        ...{for (final p in _products) p.category}.toList()..sort(),
      ];

  /// Falls back to "All" if the selected category no longer has any product.
  String get selectedCategory =>
      categories.contains(_selectedCategory) ? _selectedCategory : allCategories;

  double? get minPrice => _minPrice;
  double? get maxPrice => _maxPrice;
  bool get inStockOnly => _inStockOnly;
  ProductSort get sort => _sort;

  /// Cheapest and most expensive product, used as the ends of the price slider.
  /// (0, 0) when there are no products.
  (double, double) get priceBounds {
    if (_products.isEmpty) return (0, 0);
    var low = _products.first.price;
    var high = low;
    for (final p in _products) {
      if (p.price < low) low = p.price;
      if (p.price > high) high = p.price;
    }
    return (low.floorToDouble(), high.ceilToDouble());
  }

  /// Filters from the filter sheet (price, stock, sort) that are not at their
  /// defaults. Used for the badge on the filter button.
  int get activeFilterCount =>
      (_minPrice != null || _maxPrice != null ? 1 : 0) +
      (_inStockOnly ? 1 : 0) +
      (_sort != ProductSort.featured ? 1 : 0);

  bool get hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      selectedCategory != allCategories ||
      activeFilterCount > 0;

  /// Products matching the search text (name or description), category, price
  /// range and stock, in the chosen order.
  List<Product> get filteredProducts {
    final query = _searchQuery.trim().toLowerCase();
    final category = selectedCategory;
    final result = _products.where((product) {
      final matchesSearch = query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.description.toLowerCase().contains(query);
      final matchesCategory =
          category == allCategories || product.category == category;
      final matchesPrice = (_minPrice == null || product.price >= _minPrice!) &&
          (_maxPrice == null || product.price <= _maxPrice!);
      final matchesStock = !_inStockOnly || product.stock > 0;
      return matchesSearch && matchesCategory && matchesPrice && matchesStock;
    }).toList();

    switch (_sort) {
      case ProductSort.featured:
        break; // the order the database gave
      case ProductSort.priceLow:
        result.sort((a, b) => a.price.compareTo(b.price));
      case ProductSort.priceHigh:
        result.sort((a, b) => b.price.compareTo(a.price));
      case ProductSort.nameAZ:
        result.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    }
    return result;
  }

  /// Applies the filter sheet. A null price means "no limit on that side".
  void setFilters({
    double? minPrice,
    double? maxPrice,
    required bool inStockOnly,
    required ProductSort sort,
  }) {
    _minPrice = minPrice;
    _maxPrice = maxPrice;
    _inStockOnly = inStockOnly;
    _sort = sort;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void resetFilters() {
    _searchQuery = '';
    _selectedCategory = allCategories;
    _minPrice = null;
    _maxPrice = null;
    _inStockOnly = false;
    _sort = ProductSort.featured;
    notifyListeners();
  }

  /// Non-empty when the products could not be loaded.
  String get errorMessage => _errorMessage;

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  ProductProvider() {
    fetchProducts();
  }

  /// Returns null when the product no longer exists (e.g. deleted by the admin).
  Product? findById(String id) {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }

  void fetchProducts() {
    if (_productsSub != null) return; // already listening - never subscribe twice

    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    _loadTimer = Timer(_loadTimeout, _onLoadTimeout);

    _productsSub = _dbRef.child('products').onValue.listen((event) {
      _loadTimer?.cancel();
      final raw = event.snapshot.value;
      final loaded = <Product>[];
      if (raw is Map) {
        raw.forEach((key, value) {
          if (value is Map) {
            loaded.add(Product.fromMap(key.toString(), value));
          }
        });
      }
      _products = loaded;
      _errorMessage = '';
      _isLoading = false;
      notifyListeners();
    }, onError: (Object _) {
      _loadTimer?.cancel();
      _errorMessage = _loadError;
      _isLoading = false;
      notifyListeners();
    });
  }

  void _onLoadTimeout() {
    if (!_isLoading) return;
    _errorMessage = _loadError;
    _isLoading = false;
    notifyListeners();
  }

  /// Restarts the listener after a failed load.
  void retry() {
    _productsSub?.cancel();
    _productsSub = null;
    fetchProducts();
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    _productsSub?.cancel();
    super.dispose();
  }
}