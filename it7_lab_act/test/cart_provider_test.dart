import 'package:flutter_test/flutter_test.dart';
import 'package:it7_lab_act/features/cart/models/cart_item.dart';
import 'package:it7_lab_act/features/products/models/product.dart';

void main() {
  group('CartItem', () {
    test('totalPrice is price times quantity', () {
      final item = CartItem(
        product: Product.fromMap('p1', {'productPrice': 150.5}),
        quantity: 3,
      );
      expect(item.totalPrice, closeTo(451.5, 0.001));
    });

    test('quantity defaults to 1', () {
      final item = CartItem(product: Product.fromMap('p1', {}));
      expect(item.quantity, 1);
    });

test('equality works correctly', () {
      final item1 = CartItem(product: Product.fromMap('p1', {'productPrice': 100}), quantity: 2);
      final item2 = CartItem(product: Product.fromMap('p1', {'productPrice': 100}), quantity: 2);
      final item3 = CartItem(product: Product.fromMap('p1', {'productPrice': 100}), quantity: 3);

      // CartItem doesn't override ==, so different instances are not equal
      expect(identical(item1, item2), isFalse);
      expect(item1 == item3, isFalse);
    });
  });

  group('Product', () {
    test('fromMap reads admin dashboard keys', () {
      final product = Product.fromMap('p1', {
        'productName': '  RTX 4060  ',
        'productPrice': 18999.5,
        'productStock': 4,
        'productDescription': 'Graphics card',
        'category': 'GPU',
        'imageUrl': 'abc',
      });

      expect(product.id, 'p1');
      expect(product.name, 'RTX 4060');
      expect(product.price, 18999.5);
      expect(product.stock, 4);
      expect(product.category, 'GPU');
      expect(product.description, 'Graphics card');
      expect(product.imageUrl, 'abc');
    });

    test('accepts numbers saved as text', () {
      final product = Product.fromMap('p2', {
        'productPrice': ' 1500.25 ',
        'productStock': '3',
      });

      expect(product.price, 1500.25);
      expect(product.stock, 3);
    });

    test('uses safe defaults for missing values', () {
      final product = Product.fromMap('p3', {});

      expect(product.name, '');
      expect(product.price, 0);
      expect(product.stock, 0);
      expect(product.category, 'Uncategorized');
      expect(product.description, '');
      expect(product.imageUrl, '');
    });

    test('toMap uses the same keys', () {
      final product = Product.fromMap('p4', {
        'productName': 'SSD',
        'productPrice': 2000,
        'productStock': 10,
        'category': 'Storage',
      });

      expect(product.toMap()['productName'], 'SSD');
      expect(product.toMap()['productPrice'], 2000);
      expect(product.toMap()['productStock'], 10);
      expect(product.toMap()['category'], 'Storage');
    });
  });
}