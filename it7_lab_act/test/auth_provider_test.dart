import 'package:flutter_test/flutter_test.dart';
import 'package:it7_lab_act/features/auth/validators.dart';
import 'package:it7_lab_act/features/address/utils/address_validators.dart';
import 'package:it7_lab_act/features/address/models/shipping_address.dart';

void main() {
  group('AuthValidators', () {
    test('email validates correct format', () {
      expect(AuthValidators.email('test@example.com'), isNull);
      expect(AuthValidators.email('user.name@domain.co.uk'), isNull);
      expect(AuthValidators.email('invalid'), 'Enter a valid email, like name@example.com');
      expect(AuthValidators.email('missing@domain'), 'Enter a valid email, like name@example.com');
      expect(AuthValidators.email('@nodomain.com'), 'Enter a valid email, like name@example.com');
      expect(AuthValidators.email(''), 'Please enter your email');
      expect(AuthValidators.email('   '), 'Please enter your email');
    });

    test('name rejects empty', () {
      expect(AuthValidators.name('John Doe'), isNull);
      expect(AuthValidators.name('  Jane  '), isNull);
      expect(AuthValidators.name(''), 'Please enter your name');
      expect(AuthValidators.name('   '), 'Please enter your name');
    });

    test('newPassword enforces strong requirements', () {
      // Valid password
      expect(AuthValidators.newPassword('Abcdef1!'), isNull);
      expect(AuthValidators.newPassword('Password123@'), isNull);
      expect(AuthValidators.newPassword('MyStr0ng!Pass'), isNull);

      // Invalid passwords
      expect(AuthValidators.newPassword(''), 'Please enter a password');
      expect(AuthValidators.newPassword('short'), 'Password must be at least 8 characters');
      expect(AuthValidators.newPassword('nouppercase1!'), 'Password must contain an uppercase letter');
      expect(AuthValidators.newPassword('NOLOWERCASE1!'), 'Password must contain a lowercase letter');
      expect(AuthValidators.newPassword('NoNumbers!'), 'Password must contain a number');
      expect(AuthValidators.newPassword('NoSpecial123'), 'Password must contain a special character');
      expect(AuthValidators.newPassword('NoNumberOrSpecial!'), 'Password must contain a number');
    });

    test('confirmPassword matches original', () {
      final validator = AuthValidators.confirmPassword(() => 'password123');
      expect(validator('password123'), isNull);
      expect(validator('different'), 'Passwords do not match');
      expect(validator(''), 'Please confirm your password');
      expect(validator('password123!'), 'Passwords do not match');
    });
  });

  group('AddressValidators', () {
    test('notEmpty validates required fields', () {
      expect(AddressValidators.notEmpty('value'), isNull);
      expect(AddressValidators.notEmpty('  value  '), isNull);
      expect(AddressValidators.notEmpty(''), 'Required');
      expect(AddressValidators.notEmpty('   '), 'Required');
      expect(AddressValidators.notEmpty(null), 'Required');
      expect(AddressValidators.notEmpty('', 'Custom message'), 'Custom message');
    });

    test('zip validates 4-digit Philippine ZIP codes', () {
      expect(AddressValidators.zip('1000'), isNull);
      expect(AddressValidators.zip('1234'), isNull);
      expect(AddressValidators.zip('9999'), isNull);
      expect(AddressValidators.zip('100'), 'Enter 4 digits');
      expect(AddressValidators.zip('12345'), 'Enter 4 digits');
      expect(AddressValidators.zip('abcd'), 'Enter 4 digits');
      expect(AddressValidators.zip(''), 'Required');
    });

    test('normalizePhone handles various formats', () {
      // Standard 09 format
      expect(AddressValidators.normalizePhone('09123456789'), '09123456789');
      expect(AddressValidators.normalizePhone('0912-345-6789'), '09123456789');
      expect(AddressValidators.normalizePhone('0912 345 6789'), '09123456789');
      expect(AddressValidators.normalizePhone('(0912) 345-6789'), '09123456789');

      // +63 format
      expect(AddressValidators.normalizePhone('+639123456789'), '09123456789');
      expect(AddressValidators.normalizePhone('+63 912 345 6789'), '09123456789');
      expect(AddressValidators.normalizePhone('+63912-345-6789'), '09123456789');

      // 63 format (12 digits)
      expect(AddressValidators.normalizePhone('639123456789'), '09123456789');
    });

    test('isValidPhone validates Philippine mobile numbers', () {
      expect(AddressValidators.isValidPhone('09123456789'), isTrue);
      expect(AddressValidators.isValidPhone('+639123456789'), isTrue);
      expect(AddressValidators.isValidPhone('0912-345-6789'), isTrue);
      expect(AddressValidators.isValidPhone('0912345678'), isFalse); // too short
      expect(AddressValidators.isValidPhone('08123456789'), isFalse); // not 09
      expect(AddressValidators.isValidPhone(''), isFalse);
      expect(AddressValidators.isValidPhone(null), isFalse);
    });

    test('phone validator returns appropriate messages', () {
      expect(AddressValidators.phone('09123456789'), isNull);
      expect(AddressValidators.phone('+639123456789'), isNull);
      expect(AddressValidators.phone(''), 'Please enter your phone number');
      expect(AddressValidators.phone('0912345678'), 'Use a mobile number like 09123456789 or +639123456789');
      expect(AddressValidators.phone('08123456789'), 'Use a mobile number like 09123456789 or +639123456789');
    });
  });

  group('ShippingAddress', () {
    test('formatted returns single line address', () {
      final address = ShippingAddress(
        street: '123 Main St',
        barangay: 'Barangay 1',
        city: 'Manila',
        province: 'Metro Manila',
        zipCode: '1000',
      );
      // Implementation joins parts with ', ' then appends zipCode with space
      expect(address.formatted, '123 Main St, Brgy. Barangay 1, Manila, Metro Manila 1000');
    });

    test('formatted handles missing optional fields', () {
      final address = ShippingAddress(
        street: '123 Main St',
        city: 'Manila',
        province: 'Metro Manila',
        zipCode: '1000',
      );
      expect(address.formatted, '123 Main St, Manila, Metro Manila 1000');
    });

    test('empty returns empty formatted', () {
      expect(ShippingAddress.empty.formatted, '');
    });

    test('toMap and fromProfile work correctly', () {
      final address = ShippingAddress(
        street: '123 Main St',
        barangay: 'Barangay 1',
        city: 'Manila',
        province: 'Metro Manila',
        zipCode: '1000',
        latitude: 14.5995,
        longitude: 120.9842,
      );

      final map = address.toMap();
      expect(map['street'], '123 Main St');
      expect(map['barangay'], 'Barangay 1');
      expect(map['city'], 'Manila');
      expect(map['province'], 'Metro Manila');
      expect(map['zipCode'], '1000');
      expect(map['lat'], 14.5995);
      expect(map['lng'], 120.9842);

      final parsed = ShippingAddress.fromProfile(map, '');
      expect(parsed.street, '123 Main St');
      expect(parsed.barangay, 'Barangay 1');
      expect(parsed.city, 'Manila');
      expect(parsed.province, 'Metro Manila');
      expect(parsed.zipCode, '1000');
      expect(parsed.latitude, 14.5995);
      expect(parsed.longitude, 120.9842);
    });

    test('fromProfile handles null gracefully', () {
      final parsed = ShippingAddress.fromProfile(null, 'Fallback Address');
      expect(parsed.street, '');
      expect(parsed.formatted, 'Fallback Address');
    });

    test('fromProfile handles empty map', () {
      final parsed = ShippingAddress.fromProfile({}, 'Fallback Address');
      expect(parsed.street, '');
      expect(parsed.formatted, 'Fallback Address');
    });

    test('copyWith creates modified copy', () {
      final address = ShippingAddress(
        street: '123 Main St',
        city: 'Manila',
        province: 'Metro Manila',
        zipCode: '1000',
      );

      final copied = address.copyWith(city: 'Quezon City');
      expect(copied.city, 'Quezon City');
      expect(copied.street, '123 Main St');
    });

    test('isComplete validates complete address', () {
      final complete = ShippingAddress(
        street: '123 Main St',
        barangay: 'Barangay 1',
        city: 'Manila',
        province: 'Metro Manila',
        zipCode: '1000',
      );
      expect(complete.isComplete, isTrue);

      final incomplete = ShippingAddress(street: '123 Main St');
      expect(incomplete.isComplete, isFalse);
    });
  });
}