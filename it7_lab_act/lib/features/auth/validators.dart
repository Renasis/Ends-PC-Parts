/// Form validators shared by the login and sign up screens.
class AuthValidators {
  AuthValidators._();

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) return 'Please enter your name';
    return null;
  }

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Please enter your email';
    if (!_emailPattern.hasMatch(text)) {
      return 'Enter a valid email, like name@example.com';
    }
    return null;
  }

  /// Strong password: 8+ chars, uppercase, lowercase, number, special char.
  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) return 'Please enter a password';
    if (value.length < 8) return 'Password must be at least 8 characters';
    if (!value.contains(RegExp(r'[A-Z]'))) return 'Password must contain an uppercase letter';
    if (!value.contains(RegExp(r'[a-z]'))) return 'Password must contain a lowercase letter';
    if (!value.contains(RegExp(r'[0-9]'))) return 'Password must contain a number';
    if (!value.contains(RegExp(r'[!@#$%^&*]'))) return 'Password must contain a special character';
    return null;
  }

  static String? loginPassword(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your password';
    return null;
  }

  static String? Function(String?) confirmPassword(String Function() original) {
    return (value) {
      if (value == null || value.isEmpty) return 'Please confirm your password';
      if (value != original()) return 'Passwords do not match';
      return null;
    };
  }
}
