import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/ui/form_validators.dart';

void main() {
  group('validateEmail', () {
    test('asks for an email when empty', () {
      expect(validateEmail('  '), 'Enter your email');
    });

    test('rejects an address without a domain', () {
      expect(validateEmail('juan@'), 'Enter a valid email, like juan@mail.com');
    });

    test('accepts a normal address with surrounding spaces', () {
      expect(validateEmail(' juan@mail.com '), isNull);
    });
  });

  group('validateNewPassword', () {
    test('requires at least 8 characters', () {
      expect(validateNewPassword('abc1234'), 'Use at least 8 characters');
    });

    test('accepts 8 or more characters', () {
      expect(validateNewPassword('abcd1234'), isNull);
    });
  });

  group('validateRequired', () {
    test('names the missing field', () {
      expect(validateRequired('', 'your password'), 'Enter your password');
    });

    test('passes when filled', () {
      expect(validateRequired('x', 'your password'), isNull);
    });
  });

  group('validateName', () {
    test('asks for a name when blank', () {
      expect(validateName('   '), 'Enter your name');
    });

    test('rejects names over 50 characters', () {
      expect(validateName('a' * 51), 'Keep it under 50 characters');
    });

    test('accepts a normal name', () {
      expect(validateName('Juan Dela Cruz'), isNull);
    });
  });
}
