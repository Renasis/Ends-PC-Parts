enum PaymentProofType { screenshot, reference }

/// What the customer submits to show they paid with an online method.
///
/// A reference proof is saved on the order as `referenceNumber` and `paidAt`
/// (milliseconds since epoch). A screenshot is too big to live on the order,
/// so it is saved separately at `paymentProofs/{orderId}` (see
/// CheckoutService.placeOrder) and the order only gets `hasProofImage: true`.
class PaymentProof {
  final PaymentProofType type;
  final String? imageDataUrl;
  final String? referenceNumber;
  final DateTime? paidAt;

  const PaymentProof.screenshot(String this.imageDataUrl)
      : type = PaymentProofType.screenshot,
        referenceNumber = null,
        paidAt = null;

  const PaymentProof.reference({
    required String this.referenceNumber,
    required DateTime this.paidAt,
  })  : type = PaymentProofType.reference,
        imageDataUrl = null;

  Map<String, Object?> toOrderFields() {
    switch (type) {
      case PaymentProofType.screenshot:
        return {'hasProofImage': true};
      case PaymentProofType.reference:
        return {
          'referenceNumber': referenceNumber,
          'paidAt': paidAt?.millisecondsSinceEpoch,
        };
    }
  }
}