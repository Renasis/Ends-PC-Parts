import 'package:firebase_database/firebase_database.dart';

/// Loads the full-size picture of one product from `productImages/{id}`.
///
/// The product list only carries a small thumbnail (`products/{id}/imageUrl`),
/// so the big picture is fetched here, once, when a product page is opened.
class ProductImageService {
  /// Pictures already downloaded in this session, so reopening a product
  /// does not download it again.
  static final Map<String, String> _cache = {};

  final DatabaseReference _root;

  ProductImageService({DatabaseReference? root})
      : _root = root ?? FirebaseDatabase.instance.ref();

  /// Returns the full image as base64, or null when the admin has not saved
  /// one for this product (the thumbnail is then the only picture).
  Future<String?> loadFull(String productId) async {
    final cached = _cache[productId];
    if (cached != null) return cached;

    final snapshot = await _root.child('productImages').child(productId).get();
    final value = snapshot.value;
    if (value is! String || value.trim().isEmpty) return null;

    return _cache[productId] = value;
  }
}