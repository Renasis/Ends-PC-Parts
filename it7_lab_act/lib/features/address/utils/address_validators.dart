/// Form checks shared by the profile sheet and the checkout address form.
class AddressValidators {
  AddressValidators._();

  // Accepts 09xxxxxxxxx or +639xxxxxxxxx (Philippine mobile formats)
  static final _mobile = RegExp(r'^(?:09|\+639)\d{9}$');
  static final _zip = RegExp(r'^\d{4}$');

  static String? notEmpty(String? value, [String message = 'Required']) =>
      value == null || value.trim().isEmpty ? message : null;

  /// Philippine ZIP codes are exactly four digits.
  static String? zip(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Required';
    if (!_zip.hasMatch(text)) return 'Enter 4 digits';
    return null;
  }

  /// Turns "+63 912 345 6789", "0912-345-6789" or "639123456789" into
  /// "09123456789" so every saved number looks the same.
  static String normalizePhone(String raw) {
    var text = raw.replaceAll(RegExp(r'[\s\-()]'), '');
    if (text.startsWith('+63')) {
      text = '0${text.substring(3)}';
    } else if (text.startsWith('63') && text.length == 12) {
      text = '0${text.substring(2)}';
    }
    return text;
  }

  static bool isValidPhone(String? value) =>
      _mobile.hasMatch(normalizePhone(value ?? ''));

  /// A Philippine mobile number, so the rider can call or text.
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your phone number';
    }
    if (!isValidPhone(value)) {
      return 'Use a mobile number like 09123456789 or +639123456789';
    }
    return null;
  }
}
