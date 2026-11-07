import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/error_state.dart';
import '../providers/product_provider.dart';
import '../widgets/category_chips.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/no_results_state.dart';
import '../widgets/product_grid.dart';
import '../widgets/shop_search_bar.dart';

/// Body of the "Shop" tab: search, category chips and the product grid.
/// The search and category state live in [ProductProvider].
class ShopTab extends StatefulWidget {
  const ShopTab({super.key});

  @override
  State<ShopTab> createState() => _ShopTabState();
}

class _ShopTabState extends State<ShopTab> {
  final _searchController = TextEditingController();
  late final ProductProvider _provider;

  /// Waits for a short pause in typing before filtering the whole list.
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _provider = context.read<ProductProvider>();
    _syncSearchText();
    _provider.addListener(_syncSearchText);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _provider.removeListener(_syncSearchText);
    _searchController.dispose();
    super.dispose();
  }

  /// Keeps the text box in step when the filters are reset from elsewhere
  /// (for example "See All" on the Home tab).
  void _syncSearchText() {
    if (_searchDebounce?.isActive ?? false) return; // the customer is typing
    if (_searchController.text != _provider.searchQuery) {
      _searchController.text = _provider.searchQuery;
    }
  }

  void _onSearchChanged(String text) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _provider.setSearchQuery(text),
    );
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _provider.setSearchQuery('');
  }

  Future<void> _openFilters() async {
    final provider = context.read<ProductProvider>();
    final result = await showFilterSheet(
      context,
      priceBounds: provider.priceBounds,
      current: ProductFilters(
        minPrice: provider.minPrice,
        maxPrice: provider.maxPrice,
        inStockOnly: provider.inStockOnly,
        sort: provider.sort,
      ),
    );
    if (result == null) return;
    provider.setFilters(
      minPrice: result.minPrice,
      maxPrice: result.maxPrice,
      inStockOnly: result.inStockOnly,
      sort: result.sort,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();

    if (provider.isLoading && provider.products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.errorMessage.isNotEmpty && provider.products.isEmpty) {
      return ErrorState(
        message: provider.errorMessage,
        onRetry: provider.retry,
      );
    }
    if (provider.products.isEmpty) {
      return const Center(
        child: Text(
          'No products available yet.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final products = provider.filteredProducts;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: ShopSearchBar(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      onClear: _clearSearch,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Badge(
                    isLabelVisible: provider.activeFilterCount > 0,
                    label: Text('${provider.activeFilterCount}'),
                    child: IconButton.filledTonal(
                      tooltip: 'Filter & sort',
                      onPressed: _openFilters,
                      icon: const Icon(Icons.tune),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CategoryChips(
                categories: provider.categories,
                selected: provider.selectedCategory,
                onSelected: provider.setCategory,
              ),
            ],
          ),
        ),
        Expanded(
          child: products.isEmpty
              ? NoResultsState(onReset: provider.resetFilters)
              : ProductGrid(products: products),
        ),
      ],
    );
  }
}