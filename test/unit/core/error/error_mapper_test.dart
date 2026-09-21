import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finance/core/error/error_mapper.dart';
import 'package:finance/core/l10n/app_localizations.dart';

void main() {
  late AppLocalizations vi;
  late AppLocalizations en;

  setUpAll(() async {
    vi = await AppLocalizations.delegate.load(const Locale('vi'));
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('mapErrorToMessage (FR-007–FR-010)', () {
    test(
      'invalid_credentials AuthApiException maps to the invalid-credentials message',
      () {
        const error = AuthApiException(
          'Invalid login credentials',
          statusCode: '400',
          code: 'invalid_credentials',
        );
        expect(mapErrorToMessage(error, vi), vi.errorMapperInvalidCredentials);
        expect(mapErrorToMessage(error, en), en.errorMapperInvalidCredentials);
      },
    );

    test(
      'email_exists AuthApiException maps to the same text as signUpDuplicateEmailError (FR-013)',
      () {
        const error = AuthApiException(
          'User already registered',
          statusCode: '422',
          code: 'email_exists',
        );
        expect(mapErrorToMessage(error, vi), vi.signUpDuplicateEmailError);
        expect(mapErrorToMessage(error, en), en.signUpDuplicateEmailError);
      },
    );

    test(
      'user_already_exists AuthApiException also maps to the duplicate-email message',
      () {
        const error = AuthApiException(
          'User already registered',
          statusCode: '422',
          code: 'user_already_exists',
        );
        expect(mapErrorToMessage(error, vi), vi.errorMapperEmailExists);
      },
    );

    test(
      'weak_password AuthApiException maps to the weak-password message',
      () {
        const error = AuthApiException(
          'Password is too weak',
          statusCode: '422',
          code: 'weak_password',
        );
        expect(mapErrorToMessage(error, vi), vi.errorMapperWeakPassword);
        expect(mapErrorToMessage(error, en), en.errorMapperWeakPassword);
      },
    );

    test(
      'a real AuthWeakPasswordException instance ALSO maps to the weak-password message '
      '(regression guard: this subtype extends AuthException directly, not AuthApiException — '
      'research.md Decision 2)',
      () {
        final error = AuthWeakPasswordException(
          message: 'Password is too weak',
          statusCode: '422',
          reasons: const ['too_short'],
        );
        expect(mapErrorToMessage(error, vi), vi.errorMapperWeakPassword);
        expect(mapErrorToMessage(error, en), en.errorMapperWeakPassword);
      },
    );

    test(
      'over_email_send_rate_limit AuthApiException maps to the rate-limited message',
      () {
        const error = AuthApiException(
          'Too many requests',
          statusCode: '429',
          code: 'over_email_send_rate_limit',
        );
        expect(mapErrorToMessage(error, vi), vi.errorMapperRateLimited);
        expect(mapErrorToMessage(error, en), en.errorMapperRateLimited);
      },
    );

    test('SocketException maps to the network-failure message', () {
      final error = SocketException('Connection refused');
      expect(mapErrorToMessage(error, vi), vi.errorMapperNetworkFailure);
      expect(mapErrorToMessage(error, en), en.errorMapperNetworkFailure);
    });

    test('TimeoutException maps to the network-failure message', () {
      final error = TimeoutException('timed out');
      expect(mapErrorToMessage(error, vi), vi.errorMapperNetworkFailure);
    });

    test('AuthRetryableFetchException maps to the network-failure message', () {
      final error = AuthRetryableFetchException(message: 'Network error');
      expect(mapErrorToMessage(error, vi), vi.errorMapperNetworkFailure);
      expect(mapErrorToMessage(error, en), en.errorMapperNetworkFailure);
    });

    test(
      'an unrecognized exception type falls back to the generic message (SC-004)',
      () {
        final error = Exception('boom');
        expect(mapErrorToMessage(error, vi), vi.errorMapperGeneric);
        expect(mapErrorToMessage(error, en), en.errorMapperGeneric);
      },
    );

    test('a PostgrestException falls back to the generic message', () {
      const error = PostgrestException(message: 'duplicate key value');
      expect(mapErrorToMessage(error, vi), vi.errorMapperGeneric);
    });

    test(
      'an unrecognized AuthApiException code falls back to the generic message',
      () {
        const error = AuthApiException(
          'Something else',
          statusCode: '400',
          code: 'some_future_error_code',
        );
        expect(mapErrorToMessage(error, vi), vi.errorMapperGeneric);
      },
    );
  });
}
