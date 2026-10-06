import 'package:flutter_test/flutter_test.dart';

import 'package:finance/features/account/domain/password_policy.dart';

void main() {
  group('PasswordPolicy.minLength', () {
    test('is 8', () {
      expect(PasswordPolicy.minLength, 8);
    });
  });

  group('PasswordPolicy.meetsMinimum', () {
    test('rejects 7 characters', () {
      expect(PasswordPolicy.meetsMinimum('1234567'), isFalse);
    });

    test('accepts exactly 8 characters', () {
      expect(PasswordPolicy.meetsMinimum('12345678'), isTrue);
    });

    test('accepts a long password', () {
      expect(PasswordPolicy.meetsMinimum('a' * 64), isTrue);
    });

    test('rejects an empty password', () {
      expect(PasswordPolicy.meetsMinimum(''), isFalse);
    });

    test('does not trim: 8 spaces count as 8 characters', () {
      expect(PasswordPolicy.meetsMinimum('        '), isTrue);
    });

    test('does not trim: surrounding spaces do not pad a short password', () {
      expect(PasswordPolicy.meetsMinimum('  abc  '), isFalse);
    });

    test('counts precomposed Vietnamese letters as one character each', () {
      // 'mậtkhẩu1' is m, ậ, t, k, h, ẩ, u, 1 = 8 code points
      // (but more bytes in UTF-8).
      expect(PasswordPolicy.meetsMinimum('mậtkhẩu1'), isTrue);
    });

    test('counts an emoji as one character', () {
      const emoji = '\u{1F600}';
      expect(PasswordPolicy.meetsMinimum('abcdefg$emoji'), isTrue);
      expect(PasswordPolicy.meetsMinimum('abcdefg'), isFalse);
      // 7 characters including an emoji (UTF-16 length 8) stays too short.
      expect(PasswordPolicy.meetsMinimum('abcdef$emoji'), isFalse);
    });

    test('has no composition rules', () {
      expect(PasswordPolicy.meetsMinimum('aaaaaaaa'), isTrue);
      expect(PasswordPolicy.meetsMinimum('11111111'), isTrue);
    });
  });

  group('PasswordPolicy.differs', () {
    test('is false for identical passwords', () {
      expect(PasswordPolicy.differs('a', 'a'), isFalse);
    });

    test('is true for different passwords', () {
      expect(PasswordPolicy.differs('a', 'b'), isTrue);
    });

    test('is case sensitive', () {
      expect(PasswordPolicy.differs('Abcdefgh', 'abcdefgh'), isTrue);
    });
  });

  group('PasswordPolicy.matches', () {
    test('is true for identical passwords', () {
      expect(PasswordPolicy.matches('x', 'x'), isTrue);
    });

    test('is false for different passwords', () {
      expect(PasswordPolicy.matches('x', 'y'), isFalse);
    });
  });
}
