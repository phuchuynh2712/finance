import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finance/features/account/application/auth_error_mapper.dart';

void main() {
  test('recognizes the email_exists sign-up code', () {
    const error = AuthApiException(
      'User already registered',
      statusCode: '422',
      code: 'email_exists',
    );

    expect(isDuplicateSignUpError(error), isTrue);
  });

  test('recognizes the user_already_exists sign-up code', () {
    const error = AuthApiException(
      'User already registered',
      statusCode: '422',
      code: 'user_already_exists',
    );

    expect(isDuplicateSignUpError(error), isTrue);
  });

  test('does not classify unrelated errors as duplicate sign-up errors', () {
    const error = AuthApiException(
      'Invalid credentials',
      statusCode: '400',
      code: 'invalid_credentials',
    );

    expect(isDuplicateSignUpError(error), isFalse);
    expect(isDuplicateSignUpError(StateError('failed')), isFalse);
  });
}
