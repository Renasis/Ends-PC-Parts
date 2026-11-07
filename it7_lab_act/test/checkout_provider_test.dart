import 'package:flutter_test/flutter_test.dart';
import 'package:it7_lab_act/features/checkout/models/payment_method.dart';
import 'package:it7_lab_act/features/checkout/models/payment_proof.dart';

void main() {
  group('PaymentMethod', () {
    test('COD is not online', () {
      expect(PaymentMethod.cod.isOnline, isFalse);
      expect(PaymentMethod.cod.initialPaymentStatus, 'Unpaid');
      expect(PaymentMethod.cod.label, 'COD');
      expect(PaymentMethod.cod.key, 'cod');
    });

    test('online methods have pending_verification', () {
      const method = PaymentMethod(key: 'gcash', label: 'GCash');
      expect(method.isOnline, isTrue);
      expect(method.initialPaymentStatus, 'pending_verification');
    });

    test('custom payment method with bank', () {
      const method = PaymentMethod(key: 'bpi', label: 'BPI Bank Transfer', bankName: 'BPI');
      expect(method.key, 'bpi');
      expect(method.label, 'BPI Bank Transfer');
      expect(method.isOnline, isTrue);
      expect(method.bankName, 'BPI');
      expect(method.initialPaymentStatus, 'pending_verification');
    });

    test('subtitle shows correct text', () {
      expect(PaymentMethod.cod.subtitle, 'Cash on Delivery - pay when your order arrives');
      
      const online = PaymentMethod(key: 'gcash', label: 'GCash');
      expect(online.subtitle, 'Send your payment, then submit the proof');
    });

    test('hasDistinctBankName detects bank names', () {
      const gcash = PaymentMethod(key: 'gcash', label: 'GCash');
      expect(gcash.hasDistinctBankName, isFalse);

      const bpi = PaymentMethod(key: 'bpi', label: 'BPI Bank Transfer', bankName: 'BPI');
      expect(bpi.hasDistinctBankName, isFalse); // bankName == key

      const custom = PaymentMethod(key: 'custom', label: 'Custom Bank', bankName: 'BPI');
      expect(custom.hasDistinctBankName, isTrue);
    });

    test('fromSettings reads from admin config', () {
      final method = PaymentMethod.fromSettings('gcash', {
        'providerName': 'GCash',
        'bankName': 'GCash',
        'accountName': 'Test Account',
        'accountNumber': '09123456789',
        'qrImage': 'base64data',
      });
      
      expect(method.key, 'gcash');
      expect(method.label, 'GCash');
      expect(method.bankName, 'GCash');
      expect(method.accountName, 'Test Account');
      expect(method.accountNumber, '09123456789');
      expect(method.qrImage, 'base64data');
    });

    test('knownLabels maps known keys to labels', () {
      final gcash = PaymentMethod.fromSettings('gcash', {});
      expect(gcash.label, 'GCash');

      final maya = PaymentMethod.fromSettings('maya', {});
      expect(maya.label, 'Maya');

      final bpi = PaymentMethod.fromSettings('bpi', {});
      expect(bpi.label, 'BPI Bank Transfer');

      final bdo = PaymentMethod.fromSettings('bdo', {});
      expect(bdo.label, 'BDO Bank Transfer');

      final unknown = PaymentMethod.fromSettings('unknown', {});
      expect(unknown.label, 'UNKNOWN');
    });
  });

  group('PaymentProof', () {
    test('screenshot proof stores base64', () {
      const proof = PaymentProof.screenshot('data:image/jpeg;base64,abc123');
      expect(proof.imageDataUrl, 'data:image/jpeg;base64,abc123');
      expect(proof.referenceNumber, isNull);
      expect(proof.paidAt, isNull);
      expect(proof.type, PaymentProofType.screenshot);
    });

    test('reference proof stores ref and timestamp', () {
      final now = DateTime.now();
      final proof = PaymentProof.reference(referenceNumber: 'REF123', paidAt: now);
      expect(proof.referenceNumber, 'REF123');
      expect(proof.paidAt, equals(now));
      expect(proof.imageDataUrl, isNull);
      expect(proof.type, PaymentProofType.reference);
    });

    test('toOrderFields returns correct fields for screenshot', () {
      const proof = PaymentProof.screenshot('data:image/jpeg;base64,abc');
      final fields = proof.toOrderFields();
      expect(fields['hasProofImage'], true);
      expect(fields.containsKey('referenceNumber'), isFalse);
      expect(fields.containsKey('paidAt'), isFalse);
    });

    test('toOrderFields returns correct fields for reference', () {
      final now = DateTime(2024, 1, 15, 10, 30);
      final proof = PaymentProof.reference(referenceNumber: 'REF123', paidAt: now);
      final fields = proof.toOrderFields();
      expect(fields['referenceNumber'], 'REF123');
      expect(fields['paidAt'], now.millisecondsSinceEpoch);
      expect(fields.containsKey('hasProofImage'), isFalse);
    });

    test('equality works correctly', () {
      const proof1 = PaymentProof.screenshot('data:image/jpeg;base64,abc');
      const proof2 = PaymentProof.screenshot('data:image/jpeg;base64,abc');
      const proof3 = PaymentProof.screenshot('data:image/jpeg;base64,def');
      
      expect(proof1 == proof2, isTrue);
      expect(proof1 == proof3, isFalse);
    });
  });

  group('PaymentProofType', () {
    test('has correct values', () {
      expect(PaymentProofType.values, [PaymentProofType.screenshot, PaymentProofType.reference]);
    });
  });
}