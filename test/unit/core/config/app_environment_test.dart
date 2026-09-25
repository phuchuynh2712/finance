import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/config/app_environment.dart';

void main() {
  group('AppEnvironment.isValidWebRedirectUrl (FR-004, Clarification 1)', () {
    test('a real https:// URL is valid', () {
      expect(
        AppEnvironment.isValidWebRedirectUrl(
          'https://app.example.com/reset-callback',
        ),
        isTrue,
      );
    });

    test('http://localhost is valid (loopback exemption)', () {
      expect(
        AppEnvironment.isValidWebRedirectUrl(
          'http://localhost:5000/reset-callback',
        ),
        isTrue,
      );
    });

    test('http://127.0.0.1 is valid (loopback exemption)', () {
      expect(
        AppEnvironment.isValidWebRedirectUrl(
          'http://127.0.0.1:5000/reset-callback',
        ),
        isTrue,
      );
    });

    test('a non-loopback http:// URL is invalid', () {
      expect(
        AppEnvironment.isValidWebRedirectUrl(
          'http://app.example.com/reset-callback',
        ),
        isFalse,
      );
    });

    test('an empty value is invalid', () {
      expect(AppEnvironment.isValidWebRedirectUrl(''), isFalse);
    });

    test('an unparseable value is invalid', () {
      expect(AppEnvironment.isValidWebRedirectUrl('not a url'), isFalse);
    });

    test('a scheme-less value is invalid', () {
      expect(AppEnvironment.isValidWebRedirectUrl('example.com'), isFalse);
    });
  });
}
