import 'package:flutter_test/flutter_test.dart';

import 'package:finance/features/account/presentation/sign_up_validation.dart';

void main() {
  group('SignUpValidation.isEmailValid', () {
    test('accepts a well-formed email', () {
      expect(SignUpValidation.isEmailValid('user@example.com'), isTrue);
    });

    test('rejects a string with no @', () {
      expect(SignUpValidation.isEmailValid('userexample.com'), isFalse);
    });

    test('rejects a string with no domain', () {
      expect(SignUpValidation.isEmailValid('user@'), isFalse);
    });

    test('rejects a string with no TLD', () {
      expect(SignUpValidation.isEmailValid('user@example'), isFalse);
    });

    test('rejects an empty string', () {
      expect(SignUpValidation.isEmailValid(''), isFalse);
    });
  });

  group('SignUpValidation.isPasswordValid', () {
    test('accepts a password of exactly the minimum length', () {
      expect(SignUpValidation.isPasswordValid('123456'), isTrue);
    });

    test('accepts a password longer than the minimum', () {
      expect(SignUpValidation.isPasswordValid('a-very-long-password'), isTrue);
    });

    test('rejects a password shorter than the minimum', () {
      expect(SignUpValidation.isPasswordValid('12345'), isFalse);
    });

    test('rejects an empty password', () {
      expect(SignUpValidation.isPasswordValid(''), isFalse);
    });
  });

  group('SignUpValidation.isConfirmPasswordValid', () {
    test('accepts a confirmation that exactly matches the password', () {
      expect(
        SignUpValidation.isConfirmPasswordValid('password123', 'password123'),
        isTrue,
      );
    });

    test('rejects a confirmation that differs from the password', () {
      expect(
        SignUpValidation.isConfirmPasswordValid('password123', 'password124'),
        isFalse,
      );
    });

    test('rejects an empty confirmation when the password is non-empty', () {
      expect(
        SignUpValidation.isConfirmPasswordValid('password123', ''),
        isFalse,
      );
    });

    test('is case-sensitive', () {
      expect(
        SignUpValidation.isConfirmPasswordValid('Password123', 'password123'),
        isFalse,
      );
    });
  });
}
