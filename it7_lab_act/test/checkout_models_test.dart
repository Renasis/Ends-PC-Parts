import 'package:flutter_test/flutter_test.dart';
import 'package:it7_lab_act/features/checkout/models/checkout_settings.dart';
import 'package:it7_lab_act/features/checkout/models/payment_method.dart';
import 'package:it7_lab_act/features/checkout/models/payment_proof.dart';

void main() {
  group('CheckoutSettings.fromMap', () {
    test('missing fee means free shipping and COD is the only method', () {
      final settings = CheckoutSettings.fromMap({});

      expect(settings.shippingFee, 0);
      expect(settings.paymentMethods.map((m) => m.key), ['cod']);
    });

    test('negative fee becomes zero', () {
      expect(CheckoutSettings.fromMap({'shippingFee': -50}).shippingFee, 0);
    });

    test('fee saved as text is understood', () {
      expect(CheckoutSettings.fromMap({'shippingFee': '120'}).shippingFee, 120);
    });

    test('COD comes first, then the admin methods sorted by key', () {
      final settings = CheckoutSettings.fromMap({
        'shippingFee': 100,
        'paymentMethods': {
          'maya': {'accountNumber': '0917'},
          'gcash': {'accountNumber': '0918'},
        },
      });

      expect(settings.paymentMethods.map((m) => m.key),
          ['cod', 'gcash', 'maya']);
      expect(settings.paymentMethods[1].label, 'GCash');
    });
  });

  group('PaymentMethod', () {
    test('COD is not online and starts unpaid', () {
      expect(PaymentMethod.cod.isOnline, isFalse);
      expect(PaymentMethod.cod.initialPaymentStatus, 'Unpaid');
    });

    test('online methods wait for verification', () {
      final gcash = PaymentMethod.fromSettings('gcash', {});

      expect(gcash.isOnline, isTrue);
      expect(gcash.initialPaymentStatus, 'pending_verification');
    });
  });

  group('PaymentProof.toOrderFields', () {
    test('a screenshot only marks the order', () {
      const proof = PaymentProof.screenshot('data:image/png;base64,AAAA');

      expect(proof.toOrderFields(), {'hasProofImage': true});
    });

    test('a reference saves the number and time', () {
      final paidAt = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      final proof =
          PaymentProof.reference(referenceNumber: 'ABC123', paidAt: paidAt);

      expect(proof.toOrderFields(), {
        'referenceNumber': 'ABC123',
        'paidAt': 1700000000000,
      });
    });
  });
}
