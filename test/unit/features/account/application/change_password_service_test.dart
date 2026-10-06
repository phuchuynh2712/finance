import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finance/core/auth/password_change_gateway.dart';
import 'package:finance/features/account/application/change_password_service.dart';

const _current = 'old-password-1';
const _next = 'new-password-2';

class _FakeSession implements VerifiedPasswordSession {
  _FakeSession(this._log);

  final List<String> _log;
  Object? setError;
  Object? handOverError;

  @override
  Future<void> setNewPassword(String newPassword) async {
    _log.add('setNewPassword:$newPassword');
    if (setError != null) throw setError!;
  }

  @override
  Future<void> continueOnThisDevice() async {
    _log.add('continueOnThisDevice');
    if (handOverError != null) throw handOverError!;
  }

  @override
  Future<void> close() async {
    _log.add('close');
  }
}

class _FakeGateway implements PasswordChangeGateway {
  final log = <String>[];
  Object? ensureError;
  Object? verifyError;
  Object? endError;
  late final _FakeSession session = _FakeSession(log);

  @override
  Future<void> ensureSessionActive() async {
    log.add('ensureSessionActive');
    if (ensureError != null) throw ensureError!;
  }

  @override
  Future<VerifiedPasswordSession> verifyCurrentPassword(
    String currentPassword,
  ) async {
    log.add('verify:$currentPassword');
    if (verifyError != null) throw verifyError!;
    return session;
  }

  @override
  Future<void> endOtherSessions() async {
    log.add('endOtherSessions');
    if (endError != null) throw endError!;
  }
}

AuthApiException _api(String code, {String status = '400'}) =>
    AuthApiException('msg', statusCode: status, code: code);

Future<ChangePasswordResult> _change(_FakeGateway gateway) =>
    ChangePasswordService(
      gateway,
    ).change(currentPassword: _current, newPassword: _next);

void main() {
  late _FakeGateway gateway;

  setUp(() => gateway = _FakeGateway());

  group('success', () {
    test('runs session check, verify, set, hand over, close, end others — in '
        'order', () async {
      final result = await _change(gateway);

      expect(result.outcome, ChangePasswordOutcome.changed);
      expect(result.error, isNull);
      expect(gateway.log, [
        'ensureSessionActive',
        'verify:$_current',
        'setNewPassword:$_next',
        'continueOnThisDevice',
        'close',
        'endOtherSessions',
      ]);
    });
  });

  group('step 3 — keep this device signed in', () {
    // The server revokes every other session when a password is updated and
    // keeps only the one that did it (the temporary session). Without the hand
    // over this device would be signed out right after a successful change.
    test(
      'a failing hand over reports changedOthersNotEnded with the error, '
      'still closes (revokes) the temporary session and stops there',
      () async {
        final error = AuthRetryableFetchException(message: 'offline');
        gateway.session.handOverError = error;

        final result = await _change(gateway);

        expect(result.outcome, ChangePasswordOutcome.changedOthersNotEnded);
        expect(result.error, same(error));
        expect(gateway.log, [
          'ensureSessionActive',
          'verify:$_current',
          'setNewPassword:$_next',
          'continueOnThisDevice',
          'close',
        ]);
      },
    );

    test(
      'the hand over only happens after the password was really set',
      () async {
        gateway.session.setError = _api('weak_password', status: '422');

        await _change(gateway);

        expect(gateway.log, isNot(contains('continueOnThisDevice')));
      },
    );
  });

  group('step 0 — this device\'s own session', () {
    test(
      'a revoked refresh token is sessionExpired and nothing else runs',
      () async {
        final error = _api('refresh_token_not_found');
        gateway.ensureError = error;

        final result = await _change(gateway);

        expect(result.outcome, ChangePasswordOutcome.sessionExpired);
        expect(result.error, same(error));
        expect(gateway.log, ['ensureSessionActive']);
      },
    );

    test('AuthSessionMissingException is sessionExpired', () async {
      gateway.ensureError = AuthSessionMissingException();
      expect(
        (await _change(gateway)).outcome,
        ChangePasswordOutcome.sessionExpired,
      );
      expect(gateway.log, ['ensureSessionActive']);
    });

    test('over_request_rate_limit is sessionExpired, not rateLimited '
        '(gotrue has already signed this device out)', () async {
      gateway.ensureError = _api('over_request_rate_limit', status: '429');
      final result = await _change(gateway);
      expect(result.outcome, ChangePasswordOutcome.sessionExpired);
      expect(gateway.log, ['ensureSessionActive']);
    });

    for (final error in <Object>[
      SocketException('down'),
      TimeoutException('slow'),
      AuthRetryableFetchException(message: 'server error', statusCode: '503'),
    ]) {
      test('${error.runtimeType} is offline and nothing else runs', () async {
        gateway.ensureError = error;
        final result = await _change(gateway);
        expect(result.outcome, ChangePasswordOutcome.offline);
        expect(result.error, same(error));
        expect(gateway.log, ['ensureSessionActive']);
      });
    }

    test('anything unexpected is failed', () async {
      gateway.ensureError = StateError('boom');
      expect((await _change(gateway)).outcome, ChangePasswordOutcome.failed);
    });
  });

  group('step 1 — verify the current password', () {
    test('invalid_credentials is wrongCurrentPassword; no later step runs, '
        'not even close', () async {
      final error = _api('invalid_credentials');
      gateway.verifyError = error;

      final result = await _change(gateway);

      expect(result.outcome, ChangePasswordOutcome.wrongCurrentPassword);
      expect(result.error, same(error));
      expect(gateway.log, ['ensureSessionActive', 'verify:$_current']);
    });

    test('over_request_rate_limit is rateLimited', () async {
      gateway.verifyError = _api('over_request_rate_limit', status: '429');
      expect(
        (await _change(gateway)).outcome,
        ChangePasswordOutcome.rateLimited,
      );
    });

    test('a network error is offline', () async {
      gateway.verifyError = SocketException('down');
      expect((await _change(gateway)).outcome, ChangePasswordOutcome.offline);
    });
  });

  group('step 2 — set the new password', () {
    test(
      'same_password is sameAsCurrent; close still runs, others are not ended',
      () async {
        final error = _api('same_password', status: '422');
        gateway.session.setError = error;

        final result = await _change(gateway);

        expect(result.outcome, ChangePasswordOutcome.sameAsCurrent);
        expect(result.error, same(error));
        expect(gateway.log, [
          'ensureSessionActive',
          'verify:$_current',
          'setNewPassword:$_next',
          'close',
        ]);
      },
    );

    test('weak_password is weakPassword', () async {
      gateway.session.setError = _api('weak_password', status: '422');
      expect(
        (await _change(gateway)).outcome,
        ChangePasswordOutcome.weakPassword,
      );
    });

    test('AuthWeakPasswordException is weakPassword', () async {
      gateway.session.setError = AuthWeakPasswordException(
        message: 'too weak',
        statusCode: '422',
        reasons: const ['length'],
      );
      expect(
        (await _change(gateway)).outcome,
        ChangePasswordOutcome.weakPassword,
      );
    });

    test('over_request_rate_limit is rateLimited', () async {
      gateway.session.setError = _api('over_request_rate_limit', status: '429');
      expect(
        (await _change(gateway)).outcome,
        ChangePasswordOutcome.rateLimited,
      );
    });

    for (final code in [
      'session_expired',
      'session_not_found',
      'reauthentication_needed',
      'bad_jwt',
      'refresh_token_not_found',
      'refresh_token_already_used',
    ]) {
      test('$code is sessionExpired', () async {
        gateway.session.setError = _api(code);
        expect(
          (await _change(gateway)).outcome,
          ChangePasswordOutcome.sessionExpired,
        );
      });
    }

    test('AuthSessionMissingException is sessionExpired', () async {
      gateway.session.setError = AuthSessionMissingException();
      expect(
        (await _change(gateway)).outcome,
        ChangePasswordOutcome.sessionExpired,
      );
    });

    for (final error in <Object>[
      SocketException('down'),
      TimeoutException('slow'),
      AuthRetryableFetchException(message: 'offline'),
    ]) {
      test('${error.runtimeType} is offline', () async {
        gateway.session.setError = error;
        expect((await _change(gateway)).outcome, ChangePasswordOutcome.offline);
      });
    }

    test('any other error is failed, and close is awaited', () async {
      gateway.session.setError = StateError('boom');
      final result = await _change(gateway);
      expect(result.outcome, ChangePasswordOutcome.failed);
      expect(gateway.log.last, 'close');
      expect(gateway.log, isNot(contains('endOtherSessions')));
    });
  });

  group('step 4 — end the other sessions', () {
    test('a failure after the password changed is changedOthersNotEnded '
        'with the original error', () async {
      final error = AuthRetryableFetchException(message: 'offline');
      gateway.endError = error;

      final result = await _change(gateway);

      expect(result.outcome, ChangePasswordOutcome.changedOthersNotEnded);
      expect(result.error, same(error));
      expect(gateway.log, contains('setNewPassword:$_next'));
      expect(gateway.log.last, 'endOtherSessions');
    });
  });

  group('no secret is carried', () {
    test('the result never wraps the thrown exception', () async {
      final error = _api('weak_password', status: '422');
      gateway.session.setError = error;
      final result = await _change(gateway);
      expect(result.error, same(error));
    });

    test('the result of a success carries no error at all', () async {
      final result = await _change(gateway);
      expect(result.error, isNull);
      expect('${result.outcome}', isNot(contains(_current)));
      expect('${result.outcome}', isNot(contains(_next)));
    });
  });

  group('signOutOtherDevices (retry for changedOthersNotEnded)', () {
    test(
      'succeeds after a session check and ending the other sessions',
      () async {
        final result = await ChangePasswordService(
          gateway,
        ).signOutOtherDevices();

        expect(result.outcome, ChangePasswordOutcome.changed);
        expect(result.error, isNull);
        expect(gateway.log, ['ensureSessionActive', 'endOtherSessions']);
      },
    );

    test(
      'a failing session check returns changedOthersNotEnded with the error',
      () async {
        final error = _api('refresh_token_not_found');
        gateway.ensureError = error;

        final result = await ChangePasswordService(
          gateway,
        ).signOutOtherDevices();

        expect(result.outcome, ChangePasswordOutcome.changedOthersNotEnded);
        expect(result.error, same(error));
        expect(gateway.log, ['ensureSessionActive']);
      },
    );

    test('a failure ending the other sessions returns changedOthersNotEnded '
        'with the error', () async {
      final error = AuthRetryableFetchException(message: 'offline');
      gateway.endError = error;

      final result = await ChangePasswordService(gateway).signOutOtherDevices();

      expect(result.outcome, ChangePasswordOutcome.changedOthersNotEnded);
      expect(result.error, same(error));
    });
  });
}
