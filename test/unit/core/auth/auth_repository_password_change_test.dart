import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finance/core/auth/auth_repository.dart';

const _url = 'https://example-ref.supabase.co';
const _key = 'sb_publishable_test_key';

/// Records what the repository does to the app's own auth client; only the
/// members the password-change code uses are implemented.
class _FakeAuth extends Fake implements GoTrueClient {
  _FakeAuth({this.user, this.session});

  User? user;
  Session? session;

  final log = <String>[];
  final signOutScopes = <SignOutScope>[];
  final setSessionTokens = <String>[];

  Object? refreshError;
  Object? signOutError;
  Object? setSessionError;

  /// When set, `refreshSession` never completes, like gotrue retrying with
  /// backoff while the network is down.
  Completer<AuthResponse>? refreshGate;

  @override
  User? get currentUser => user;

  @override
  Session? get currentSession => session;

  @override
  Future<AuthResponse> refreshSession([String? refreshToken]) async {
    log.add('refreshSession');
    if (refreshGate != null) return refreshGate!.future;
    if (refreshError != null) throw refreshError!;
    return AuthResponse(session: session);
  }

  @override
  Future<AuthResponse> setSession(
    String refreshToken, {
    String? accessToken,
  }) async {
    log.add('setSession');
    setSessionTokens.add(refreshToken);
    if (setSessionError != null) throw setSessionError!;
    return AuthResponse(session: session);
  }

  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.local}) async {
    log.add('signOut');
    signOutScopes.add(scope);
    if (signOutError != null) throw signOutError!;
  }
}

class _FakeClient extends Fake implements SupabaseClient {
  _FakeClient(this._auth);

  final _FakeAuth _auth;

  @override
  GoTrueClient get auth => _auth;
}

User _user({String? email = 'qa@example.com'}) => User(
  id: 'user-1',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-01-01T00:00:00Z',
  email: email,
);

/// A session whose expiry is set explicitly (the access token is not a JWT,
/// so `expiresAt` would otherwise be null, which `isExpired` treats as live).
Session _session({Duration expiresIn = const Duration(hours: 1)}) {
  final session = Session(
    accessToken: 'app-access-token',
    tokenType: 'bearer',
    refreshToken: 'app-refresh-token',
    user: _user(),
  );
  session.expiresAt =
      DateTime.now().add(expiresIn).millisecondsSinceEpoch ~/ 1000;
  return session;
}

/// A recorded request to the (mock) Supabase Auth REST API.
class _Call {
  _Call(this.method, this.path, this.query, this.headers, this.body);

  final String method;
  final String path;
  final Map<String, String> query;
  final Map<String, String> headers;
  final Map<String, dynamic> body;
}

/// Plays the Supabase Auth server for the temporary session. Responses are
/// configurable per endpoint; every request is recorded.
class _FakeServer {
  final calls = <_Call>[];

  int tokenStatus = 200;
  Map<String, dynamic> tokenBody = {
    'access_token': 'temp-access-token',
    'refresh_token': 'temp-refresh-token',
    'token_type': 'bearer',
  };
  int updateStatus = 200;
  Map<String, dynamic> updateBody = {'id': 'user-1'};
  int logoutStatus = 204;
  Object? failWith;

  late final MockClient client = MockClient((request) async {
    final raw = request.body;
    calls.add(
      _Call(
        request.method,
        request.url.path,
        request.url.queryParameters,
        request.headers,
        raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw),
      ),
    );
    if (failWith != null) throw failWith!;
    switch (request.url.path) {
      case '/auth/v1/token':
        return http.Response(jsonEncode(tokenBody), tokenStatus);
      case '/auth/v1/user':
        return http.Response(jsonEncode(updateBody), updateStatus);
      case '/auth/v1/logout':
        return http.Response('', logoutStatus);
    }
    return http.Response('{}', 404);
  });

  List<_Call> to(String path) => calls.where((c) => c.path == path).toList();
}

class _Harness {
  _Harness({
    User? user,
    Session? session,
    bool signedOut = false,
    Duration? sessionCheckTimeout,
  }) {
    app = _FakeAuth(
      user: signedOut ? null : (user ?? _user()),
      session: signedOut ? null : (session ?? _session()),
    );
    repository = AuthRepository(
      _FakeClient(app),
      supabaseUrl: _url,
      publishableKey: _key,
      httpClient: server.client,
      sessionCheckTimeout: sessionCheckTimeout,
    );
  }

  final server = _FakeServer();
  late final _FakeAuth app;
  late final AuthRepository repository;
}

void main() {
  group('ensureSessionActive', () {
    test(
      'refreshes this device\'s own session and makes no REST call',
      () async {
        final h = _Harness();

        await h.repository.ensureSessionActive();

        expect(h.app.log, ['refreshSession']);
        expect(h.server.calls, isEmpty);
      },
    );

    test(
      'gives up with a TimeoutException when the network is down, instead of '
      'waiting out gotrue\'s ~30 s of retries (the service reads this as '
      '"offline")',
      () async {
        final h = _Harness(
          sessionCheckTimeout: const Duration(milliseconds: 50),
        );
        h.app.refreshGate = Completer<AuthResponse>();

        await expectLater(
          h.repository.ensureSessionActive(),
          throwsA(isA<TimeoutException>()),
        );
      },
    );

    test('propagates the error when the session was revoked', () async {
      final h = _Harness();
      const revoked = AuthApiException(
        'Invalid Refresh Token: Refresh Token Not Found',
        statusCode: '400',
        code: 'refresh_token_not_found',
      );
      h.app.refreshError = revoked;

      await expectLater(
        h.repository.ensureSessionActive(),
        throwsA(same(revoked)),
      );
    });
  });

  group('verifyCurrentPassword', () {
    test(
      'signs a temporary session in over REST with the app user\'s email '
      'and the given password, leaving the app\'s own client untouched',
      () async {
        final h = _Harness();

        await h.repository.verifyCurrentPassword('old-password-1');

        final calls = h.server.to('/auth/v1/token');
        expect(calls, hasLength(1));
        expect(calls.single.method, 'POST');
        expect(calls.single.query, {'grant_type': 'password'});
        expect(calls.single.headers['apikey'], _key);
        expect(calls.single.body, {
          'email': 'qa@example.com',
          'password': 'old-password-1',
        });
        expect(
          h.app.log,
          isEmpty,
          reason: 'no sign-in or event may reach the app\'s own client',
        );
      },
    );

    test('throws AuthSessionMissingException, calling nothing, when the app '
        'has no signed-in email', () async {
      final h = _Harness(signedOut: true);

      await expectLater(
        h.repository.verifyCurrentPassword('old-password-1'),
        throwsA(isA<AuthSessionMissingException>()),
      );
      expect(h.server.calls, isEmpty);
    });

    test('a wrong password surfaces invalid_credentials unchanged', () async {
      final h = _Harness();
      h.server
        ..tokenStatus = 400
        ..tokenBody = {
          'code': 400,
          'error_code': 'invalid_credentials',
          'msg': 'Invalid login credentials',
        };

      await expectLater(
        h.repository.verifyCurrentPassword('wrong-password-1'),
        throwsA(
          isA<AuthApiException>()
              .having((e) => e.code, 'code', 'invalid_credentials')
              .having((e) => e.statusCode, 'statusCode', '400'),
        ),
      );
    });

    test('rate limiting surfaces over_request_rate_limit', () async {
      final h = _Harness();
      h.server
        ..tokenStatus = 429
        ..tokenBody = {
          'code': 429,
          'error_code': 'over_request_rate_limit',
          'msg': 'Too many requests',
        };

      await expectLater(
        h.repository.verifyCurrentPassword('old-password-1'),
        throwsA(
          isA<AuthApiException>().having(
            (e) => e.code,
            'code',
            'over_request_rate_limit',
          ),
        ),
      );
    });

    test('a server error is reported like gotrue does: a retryable fetch '
        'error (so it reads as "offline")', () async {
      final h = _Harness();
      h.server
        ..tokenStatus = 503
        ..tokenBody = {'msg': 'unavailable'};

      await expectLater(
        h.repository.verifyCurrentPassword('old-password-1'),
        throwsA(isA<AuthRetryableFetchException>()),
      );
    });

    test('a network failure is a retryable fetch error', () async {
      final h = _Harness();
      h.server.failWith = const SocketException('down');

      await expectLater(
        h.repository.verifyCurrentPassword('old-password-1'),
        throwsA(isA<AuthRetryableFetchException>()),
      );
    });

    test('an error message never contains the password', () async {
      final h = _Harness();
      h.server
        ..tokenStatus = 400
        ..tokenBody = {
          'error_code': 'invalid_credentials',
          'msg': 'Invalid login credentials',
        };

      try {
        await h.repository.verifyCurrentPassword('secret-password-xyz');
        fail('expected an exception');
      } catch (error) {
        expect('$error', isNot(contains('secret-password-xyz')));
      }
    });
  });

  group('the temporary session', () {
    Future<dynamic> verified(_Harness h) =>
        h.repository.verifyCurrentPassword('old-password-1');

    test('setNewPassword updates the password with the TEMPORARY session\'s '
        'token, not the app\'s', () async {
      final h = _Harness();
      final session = await verified(h);

      await session.setNewPassword('new-password-2');

      final updates = h.server.to('/auth/v1/user');
      expect(updates, hasLength(1));
      expect(updates.single.method, 'PUT');
      expect(
        updates.single.headers['Authorization'],
        'Bearer temp-access-token',
      );
      expect(updates.single.headers['apikey'], _key);
      expect(updates.single.body, {'password': 'new-password-2'});
      expect(h.app.log, isEmpty);
    });

    test(
      'setNewPassword surfaces same_password and weak_password codes',
      () async {
        final h = _Harness();
        final session = await verified(h);

        h.server
          ..updateStatus = 422
          ..updateBody = {
            'code': 422,
            'error_code': 'same_password',
            'msg': 'New password should be different from the old password.',
          };
        await expectLater(
          session.setNewPassword('old-password-1'),
          throwsA(
            isA<AuthApiException>().having(
              (e) => e.code,
              'code',
              'same_password',
            ),
          ),
        );

        h.server.updateBody = {
          'code': 422,
          'error_code': 'weak_password',
          'msg': 'Password should be at least 8 characters.',
          'weak_password': {
            'reasons': ['length'],
          },
        };
        await expectLater(
          session.setNewPassword('short'),
          throwsA(
            isA<AuthApiException>().having(
              (e) => e.code,
              'code',
              'weak_password',
            ),
          ),
        );
      },
    );

    test('continueOnThisDevice hands the temporary session to the app\'s own '
        'client, so this device stays signed in after the server revokes its '
        'old session', () async {
      final h = _Harness();
      final session = await verified(h);
      await session.setNewPassword('new-password-2');

      await session.continueOnThisDevice();

      expect(h.app.log, ['setSession']);
      expect(h.app.setSessionTokens, ['temp-refresh-token']);
    });

    test('after continueOnThisDevice, close() must NOT revoke the session '
        '(the app is using it now)', () async {
      final h = _Harness();
      final session = await verified(h);
      await session.setNewPassword('new-password-2');
      await session.continueOnThisDevice();

      await session.close();

      expect(
        h.server.to('/auth/v1/logout'),
        isEmpty,
        reason: 'logging the temporary session out would sign this device out',
      );
    });

    test('a failing hand-over propagates, and close() then revokes the '
        'temporary session', () async {
      final h = _Harness();
      final session = await verified(h);
      final failure = AuthRetryableFetchException(message: 'offline');
      h.app.setSessionError = failure;

      await expectLater(session.continueOnThisDevice(), throwsA(same(failure)));
      await session.close();

      final logouts = h.server.to('/auth/v1/logout');
      expect(logouts, hasLength(1));
      expect(logouts.single.query, {'scope': 'local'});
      expect(
        logouts.single.headers['Authorization'],
        'Bearer temp-access-token',
      );
    });

    test('close() without hand-over revokes only the temporary session '
        '(scope local) and never throws', () async {
      final h = _Harness();
      final session = await verified(h);
      h.server.failWith = const SocketException('down');

      await session.close();

      final logouts = h.server.to('/auth/v1/logout');
      expect(logouts, hasLength(1));
      expect(logouts.single.query, {'scope': 'local'});
    });

    test('close() is idempotent', () async {
      final h = _Harness();
      final session = await verified(h);

      await session.close();
      await session.close();

      expect(h.server.to('/auth/v1/logout'), hasLength(1));
    });

    test(
      'the temporary session never touches the app\'s own sign-out',
      () async {
        final h = _Harness();
        final session = await verified(h);
        await session.setNewPassword('new-password-2');
        await session.close();

        expect(h.app.signOutScopes, isEmpty);
      },
    );
  });

  group('endOtherSessions', () {
    test('signs the other sessions out with scope others, exactly once, on the '
        'app\'s own client — never local or global', () async {
      final h = _Harness();

      await h.repository.endOtherSessions();

      expect(h.app.signOutScopes, [SignOutScope.others]);
      expect(h.server.calls, isEmpty);
    });

    test(
      'throws instead of calling the SDK when there is no session '
      '(the SDK would swallow the resulting 401 and report success)',
      () async {
        final h = _Harness(signedOut: true);

        await expectLater(
          h.repository.endOtherSessions(),
          throwsA(isA<AuthSessionMissingException>()),
        );
        expect(h.app.signOutScopes, isEmpty);
      },
    );

    test(
      'throws instead of calling the SDK when the access token has expired',
      () async {
        final h = _Harness(
          session: _session(expiresIn: const Duration(minutes: -5)),
        );

        await expectLater(
          h.repository.endOtherSessions(),
          throwsA(isA<AuthSessionMissingException>()),
        );
        expect(h.app.signOutScopes, isEmpty);
      },
    );

    test('propagates a failure from the service', () async {
      final h = _Harness();
      final failure = AuthRetryableFetchException(message: 'offline');
      h.app.signOutError = failure;

      await expectLater(
        h.repository.endOtherSessions(),
        throwsA(same(failure)),
      );
    });
  });
}
