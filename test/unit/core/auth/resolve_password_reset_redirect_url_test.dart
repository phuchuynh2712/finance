import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/auth/auth_repository.dart';

void main() {
  group(
    'resolvePasswordResetRedirectUrl (FR-004/FR-005/FR-006)',
    () {
      test('isWeb: true returns the Web redirect URL', () {
        expect(
          resolvePasswordResetRedirectUrl(
            isWeb: true,
            webRedirectUrl: 'https://app.example.com/reset-callback',
            mobileRedirectUrl: 'com.finance.finance://reset-callback',
          ),
          'https://app.example.com/reset-callback',
        );
      });

      test(
        'isWeb: false returns the mobile deep link, unchanged (FR-005)',
        () {
          expect(
            resolvePasswordResetRedirectUrl(
              isWeb: false,
              webRedirectUrl: 'https://app.example.com/reset-callback',
              mobileRedirectUrl: 'com.finance.finance://reset-callback',
            ),
            'com.finance.finance://reset-callback',
          );
        },
      );
    },
  );
}
