import 'package:flutter_test/flutter_test.dart';
import 'package:it7_lab_act/features/products/models/product.dart';

void main() {
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