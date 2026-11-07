import 'package:flutter_test/flutter_test.dart';
import 'package:it7_lab_act/features/wishlist/providers/wishlist_provider.dart';

void main() {
  group('WishlistProvider', () {
    test('initial state is empty', () {
      final provider = WishlistProvider();
      expect(provider.wishlistIds, isEmpty);
      expect(provider.isLoading, isFalse);
    });

    test('isFavorite returns false for unknown product', () {
      final provider = WishlistProvider();
      expect(provider.isFavorite('p1'), isFalse);
    });

    test('clearWishlistState clears local state', () {
      final provider = WishlistProvider();
      provider.clearWishlistState();
      expect(provider.wishlistIds, isEmpty);
    });
  });
}
