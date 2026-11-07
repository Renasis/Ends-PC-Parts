class Promo {
  final String code;
  final String discountType; // 'percentage' or 'fixed'
  final double discountValue;
  final double minSpend;

  Promo({
    required this.code,
    required this.discountType,
    required this.discountValue,
    required this.minSpend,
  });

  factory Promo.fromMap(String code, Map<dynamic, dynamic> map) {
    return Promo(
      code: code,
      discountType: map['discountType'] ?? 'fixed',
      // Convert to double safely since Firebase might store integers for whole numbers
      discountValue: (map['discountValue'] as num?)?.toDouble() ?? 0.0,
      minSpend: (map['minSpend'] as num?)?.toDouble() ?? 0.0,
    );
  }
}