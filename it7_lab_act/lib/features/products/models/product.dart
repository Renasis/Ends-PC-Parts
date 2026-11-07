/// A product as stored under `products/{id}` in the Realtime Database.
///
  /// Keys (same ones the admin dashboard writes):
  /// productName, productPrice, productStock, productDescription, category,
  /// imageUrl (base64 thumbnail), imageUrls (list of additional base64 images),
  /// variantOptions (JSON list of variant maps).
class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final int stock;
  final String category;
  final String imageUrl;

  /// Additional product images (base64 data URLs), displayed in a gallery.
  final List<String> imageUrls;

  /// Optional per-variant overrides. Each entry:
  /// { 'label': 'Size: Large', 'priceAdjustment': 50.0, 'stock': 10, 'sku': 'PC-L-001' }
  /// When empty, the product is treated as a single-variant SKU.
  final List<Map<String, dynamic>> variantOptions;

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.stock,
    required this.category,
    required this.imageUrl,
    this.imageUrls = const [],
    this.variantOptions = const [],
  });

  factory Product.fromMap(String id, Map<dynamic, dynamic> map) {
    final rawVariants = map['variantOptions'];
    List<Map<String, dynamic>> variants = [];
    if (rawVariants is List) {
      variants = rawVariants
          .whereType<Map>()
          .cast<Map<String, dynamic>>()
          .toList();
    }

    final rawImageUrls = map['imageUrls'];
    List<String> imageUrls = [];
    if (rawImageUrls is List) {
      imageUrls = rawImageUrls.whereType<String>().toList();
    }

    return Product(
      id: id,
      name: _text(map['productName']),
      description: _text(map['productDescription']),
      price: _number(map['productPrice']),
      stock: _number(map['productStock']).toInt(),
      category: _text(map['category'], fallback: 'Uncategorized'),
      imageUrl: _text(map['imageUrl']),
      imageUrls: imageUrls,
      variantOptions: variants,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productName': name,
      'productPrice': price,
      'productStock': stock,
      'productDescription': description,
      'category': category,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'variantOptions': variantOptions,
    };
  }

  /// Effective price for a variant selection (base price + adjustment).
  double priceForVariant(String variantLabel) {
    if (variantOptions.isEmpty) return price;
    final variant = variantOptions.firstWhere(
      (v) => v['label'] == variantLabel,
      orElse: () => {},
    );
    if (variant.isEmpty) return price;
    final adjustment = (variant['priceAdjustment'] as num?) ?? 0;
    return price + adjustment.toDouble();
  }

  /// Effective stock for a variant selection.
  int stockForVariant(String variantLabel) {
    if (variantOptions.isEmpty) return stock;
    final variant = variantOptions.firstWhere(
      (v) => v['label'] == variantLabel,
      orElse: () => {},
    );
    if (variant.isEmpty) return stock;
    return (variant['stock'] as num?)?.toInt() ?? stock;
  }

  /// SKU for a variant selection.
  String skuForVariant(String variantLabel) {
    if (variantOptions.isEmpty) return id;
    final variant = variantOptions.firstWhere(
      (v) => v['label'] == variantLabel,
      orElse: () => {},
    );
    if (variant.isEmpty) return id;
    return (variant['sku'] as String?)?.isNotEmpty == true
        ? variant['sku'] as String
        : id;
  }

  static String _text(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static double _number(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim()) ?? 0;
    return 0;
  }
}