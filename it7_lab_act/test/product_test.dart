import 'package:flutter_test/flutter_test.dart';
import 'package:it7_lab_act/features/cart/models/cart_item.dart';
import 'package:it7_lab_act/features/products/models/product.dart';

void main() {
  group('Product.fromMap', () {
    test('reads the keys the admin dashboard writes', () {
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
    });
  });

  group('CartItem', () {
    test('totalPrice is price times quantity', () {
      final item = CartItem(
        product: Product.fromMap('p5', {'productPrice': 250.5}),
        quantity: 3,
      );

      expect(item.totalPrice, closeTo(751.5, 0.001));
    });

    test('quantity starts at 1', () {
      final item = CartItem(product: Product.fromMap('p6', {}));

      expect(item.quantity, 1);
    });
  });
}
