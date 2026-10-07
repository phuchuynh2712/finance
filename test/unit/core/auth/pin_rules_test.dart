import 'package:finance/core/auth/pin_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('constants', () {
    test('six digits, five tries, 365 days', () {
      expect(pinLength, 6);
      expect(maxWrongTries, 5);
      expect(pinValidity, const Duration(days: 365));
    });
  });

  group('isWellFormed', () {
    test('accepts exactly six digits', () {
      expect(isWellFormed('483920'), isTrue);
      expect(isWellFormed('000000'), isTrue);
    });

    test('refuses anything else', () {
      for (final pin in [
        '',
        '12345',
        '1234567',
        '12345a',
        'abcdef',
        '12 456',
        '12345 ',
        '１２３４５６', // full-width digits
        '12345-',
      ]) {
        expect(isWellFormed(pin), isFalse, reason: '"$pin"');
      }
    });
  });

  group('isEasy', () {
    test('one digit repeated is easy', () {
      expect(isEasy('111111'), isTrue);
      expect(isEasy('000000'), isTrue);
    });

    test('a straight run up or down is easy', () {
      for (final pin in ['123456', '234567', '345678', '456789']) {
        expect(isEasy(pin), isTrue, reason: pin);
      }
      for (final pin in ['654321', '987654', '876543']) {
        expect(isEasy(pin), isTrue, reason: pin);
      }
    });

    test('repeated pairs and triples, and runs that break, are fine', () {
      for (final pin in [
        '483920',
        '121212',
        '123123',
        '112233',
        '123457',
        '901234', // wraps around: not a straight run
        '123450',
      ]) {
        expect(isEasy(pin), isFalse, reason: pin);
      }
    });

    test('a malformed PIN is not "easy", it is malformed', () {
      expect(isEasy('1234'), isFalse);
      expect(isEasy('abcdef'), isFalse);
    });
  });

  group('validate', () {
    test('null for a good PIN', () {
      expect(validate('483920'), isNull);
    });

    test('notSixDigits comes before easy', () {
      expect(validate('1111'), PinFormatError.notSixDigits);
      expect(validate(''), PinFormatError.notSixDigits);
      expect(validate('12345a'), PinFormatError.notSixDigits);
    });

    test('easy for a well-formed but guessable PIN', () {
      expect(validate('111111'), PinFormatError.easy);
      expect(validate('123456'), PinFormatError.easy);
      expect(validate('654321'), PinFormatError.easy);
    });
  });

  group('isExpired', () {
    final setAt = DateTime(2026, 1, 10, 9, 30);

    test('364 days after is still valid', () {
      expect(isExpired(setAt, setAt.add(const Duration(days: 364))), isFalse);
    });

    test('exactly 365 days after is expired', () {
      expect(isExpired(setAt, setAt.add(const Duration(days: 365))), isTrue);
    });

    test('one second before the boundary is valid, after it expired', () {
      final boundary = setAt.add(pinValidity);
      expect(
        isExpired(setAt, boundary.subtract(const Duration(seconds: 1))),
        isFalse,
      );
      expect(
        isExpired(setAt, boundary.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('a clock moved back before setAt does not expire it', () {
      expect(
        isExpired(setAt, setAt.subtract(const Duration(days: 30))),
        isFalse,
      );
    });
  });
}
