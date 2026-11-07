import 'package:flutter/material.dart';

import '../providers/product_provider.dart';

/// Result of the filter sheet. A null price means "no limit on that side".
class ProductFilters {
  final double? minPrice;
  final double? maxPrice;
  final bool inStockOnly;
  final ProductSort sort;

  const ProductFilters({
    this.minPrice,
    this.maxPrice,
    this.inStockOnly = false,
    this.sort = ProductSort.featured,
  });
}

/// Bottom sheet with the price range, "in stock only" and sort options.
/// Returns the chosen filters, or null when the customer closed it.
Future<ProductFilters?> showFilterSheet(
  BuildContext context, {
  required (double, double) priceBounds,
  required ProductFilters current,
}) {
  return showModalBottomSheet<ProductFilters>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _FilterSheet(bounds: priceBounds, current: current),
  );
}

class _FilterSheet extends StatefulWidget {
  final (double, double) bounds;
  final ProductFilters current;

  const _FilterSheet({required this.bounds, required this.current});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late RangeValues _range;
  late bool _inStockOnly;
  late ProductSort _sort;

  double get _low => widget.bounds.$1;
  double get _high => widget.bounds.$2;

  /// A slider needs a range with some width, so a shop whose products all
  /// cost the same simply gets no price slider.
  bool get _hasRange => _high > _low;

  @override
  void initState() {
    super.initState();
    final c = widget.current;
    _range = RangeValues(
      (c.minPrice ?? _low).clamp(_low, _high).toDouble(),
      (c.maxPrice ?? _high).clamp(_low, _high).toDouble(),
    );
    _inStockOnly = c.inStockOnly;
    _sort = c.sort;
  }

  void _apply() {
    // Keep "no limit" as null when the slider is at its ends, so products
    // added later (cheaper or dearer) are not hidden by an old range.
    Navigator.pop(
      context,
      ProductFilters(
        minPrice: _hasRange && _range.start > _low ? _range.start : null,
        maxPrice: _hasRange && _range.end < _high ? _range.end : null,
        inStockOnly: _inStockOnly,
        sort: _sort,
      ),
    );
  }

  void _clear() {
    Navigator.pop(context, const ProductFilters());
  }

  String _peso(double value) => '₱${value.round()}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter & Sort',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (_hasRange) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Price range',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${_peso(_range.start)} - ${_peso(_range.end)}',
                  style: TextStyle(color: scheme.primary),
                ),
              ],
            ),
            RangeSlider(
              values: _range,
              min: _low,
              max: _high,
              labels: RangeLabels(_peso(_range.start), _peso(_range.end)),
              onChanged: (values) => setState(() => _range = values),
            ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('In stock only'),
            value: _inStockOnly,
            onChanged: (value) => setState(() => _inStockOnly = value),
          ),
          const SizedBox(height: 4),
          const Text('Sort by', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final option in ProductSort.values)
                ChoiceChip(
                  label: Text(option.label),
                  selected: _sort == option,
                  onSelected: (_) => setState(() => _sort = option),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _clear,
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _apply,
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
