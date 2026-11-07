import 'address_label.dart';

/// A delivery address, split into the parts the forms need, plus an optional
/// map pin, ZIP code, a label (Home / Work / Other) and a landmark note.
///
/// Older accounts only have a single-line address; that text is kept in
/// [legacyText] when it cannot be split into parts. Accounts saved before the
/// ZIP code existed simply have an empty [zipCode].
class ShippingAddress {
  static const defaultCity = 'Binangonan';
  static const defaultProvince = 'Rizal';
  static const maxLandmarkLength = 120;

  final AddressLabel label;
  final String street;
  final String barangay;
  final String city;
  final String province;

  /// Four-digit Philippine postal code. Empty on older accounts.
  final String zipCode;

  /// Optional hint for the rider: "Blue gate beside the sari-sari store".
  final String landmark;

  final double? latitude;
  final double? longitude;
  final String legacyText;

  const ShippingAddress({
    this.label = AddressLabel.home,
    this.street = '',
    this.barangay = '',
    this.city = '',
    this.province = '',
    this.zipCode = '',
    this.landmark = '',
    this.latitude,
    this.longitude,
    this.legacyText = '',
  });

  static const empty = ShippingAddress();

  bool get hasPin => latitude != null && longitude != null;
  bool get hasZip => zipCode.isNotEmpty;
  bool get hasLandmark => landmark.isNotEmpty;

  /// True when the address was split into parts (not an old one-line text).
  bool get isStructured => street.isNotEmpty;

  /// Every part is filled in, including a valid four-digit ZIP code.
  bool get isComplete =>
      street.isNotEmpty &&
      barangay.isNotEmpty &&
      city.isNotEmpty &&
      province.isNotEmpty &&
      RegExp(r'^\d{4}$').hasMatch(zipCode);

  /// One line, as shown to the customer and saved on the order:
  /// `Street, Brgy. X, City, Province 1940 (Landmark: ...)`.
  String get formatted {
    final parts = [
      street,
      if (barangay.isNotEmpty) 'Brgy. $barangay',
      city,
      province,
    ].where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return legacyText;

    final line = hasZip ? '${parts.join(', ')} $zipCode' : parts.join(', ');
    return hasLandmark ? '$line (Landmark: $landmark)' : line;
  }

  bool get isEmpty => formatted.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// First line of the address (street), or the whole text for old accounts.
  String get primaryLine => street.isNotEmpty ? street : formatted;

  /// Second line (barangay, city, province, ZIP); empty for old single-line data.
  String get secondaryLine {
    final line = [
      if (barangay.isNotEmpty) 'Brgy. $barangay',
      city,
      province,
    ].where((p) => p.isNotEmpty).join(', ');
    if (line.isEmpty) return '';
    return hasZip ? '$line $zipCode' : line;
  }

  ShippingAddress copyWith({
    AddressLabel? label,
    String? street,
    String? barangay,
    String? city,
    String? province,
    String? zipCode,
    String? landmark,
  }) {
    return ShippingAddress(
      label: label ?? this.label,
      street: street ?? this.street,
      barangay: barangay ?? this.barangay,
      city: city ?? this.city,
      province: province ?? this.province,
      zipCode: zipCode ?? this.zipCode,
      landmark: landmark ?? this.landmark,
      latitude: latitude,
      longitude: longitude,
      legacyText: legacyText,
    );
  }

  Map<String, Object> toMap() => {
        'label': label.key,
        'street': street,
        'barangay': barangay,
        'city': city,
        'province': province,
        'zipCode': zipCode,
        'landmark': landmark,
        'lat': ?latitude,
        'lng': ?longitude,
      };

  /// Builds the address from the user's database record. [map] is the new
  /// structured `address` node (may be null); [legacyLine] is the old
  /// `deliveryAddress` text.
  factory ShippingAddress.fromProfile(Map? map, String legacyLine) {
    final line = legacyLine.trim();

    if (map != null) {
      String text(String key) => (map[key] ?? '').toString().trim();
      double? number(String key) {
        final v = map[key];
        return v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
      }

      final zip = text('zipCode').isNotEmpty ? text('zipCode') : text('zip');

      return ShippingAddress(
        label: AddressLabel.fromKey(map['label']),
        street: text('street'),
        barangay: text('barangay'),
        city: text('city'),
        province: text('province'),
        zipCode: zip,
        landmark: text('landmark'),
        latitude: number('lat'),
        longitude: number('lng'),
        legacyText: line,
      );
    }

    // Old accounts: try to split "Street, Brgy. X, City, Province [ZIP]".
    final match = RegExp(
      r'^(.+?), Brgy\. (.+?), ([^,]+), ([^,]+?)(?: (\d{4}))?$',
    ).firstMatch(line);
    if (match != null) {
      return ShippingAddress(
        street: match.group(1)!.trim(),
        barangay: match.group(2)!.trim(),
        city: match.group(3)!.trim(),
        province: match.group(4)!.trim(),
        zipCode: match.group(5) ?? '',
      );
    }
    return ShippingAddress(legacyText: line);
  }
}
