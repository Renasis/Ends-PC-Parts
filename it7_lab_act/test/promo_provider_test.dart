import 'package:flutter_test/flutter_test.dart';
import 'package:it7_lab_act/features/promos/models/promo_model.dart';
import 'package:it7_lab_act/features/promos/providers/promo_provider.dart';

Promo promo(String type, double value, {double minSpend = 0}) => Promo(
      code: 'TEST',
      discountType: type,
      discountValue: value,
      minSpend: minSpend,
    );

void main() {
  group('PromoProvider.calculateDiscount', () {
    test('is zero when no promo is applied', () {
      expect(PromoProvider().calculateDiscount(1000), 0);
    });

    test('percentage takes that share of the subtotal', () {
      final provider = PromoProvider()
        ..applyForTest(promo('percentage', 10));

      expect(provider.calculateDiscount(1000), 100);
    });

    test('fixed takes the amount off', () {
      final provider = PromoProvider()..applyForTest(promo('fixed', 150));

      expect(provider.calculateDiscount(1000), 150);
    });

    test('never discounts more than the subtotal', () {
      final provider = PromoProvider()..applyForTest(promo('fixed', 500));

      expect(provider.calculateDiscount(200), 200);
    });

    test('is zero when the subtotal is below the minimum spend', () {
      final provider = PromoProvider()
        ..applyForTest(promo('percentage', 10, minSpend: 500));

      expect(provider.calculateDiscount(499.99), 0);
      expect(provider.calculateDiscount(500), 50);
    });

    test('rounds to centavos', () {
      final provider = PromoProvider()
        ..applyForTest(promo('percentage', 10));

      expect(provider.calculateDiscount(33.33), 3.33);
    });

    test('removePromo clears the discount', () {
      final provider = PromoProvider()
        ..applyForTest(promo('percentage', 10))
        ..removePromo();

      expect(provider.appliedPromo, isNull);
      expect(provider.calculateDiscount(1000), 0);
    });
  });
}
