import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finance/core/auth/auth_repository.dart';
import 'package:finance/core/auth/pin_lock_repository.dart';
import 'package:finance/features/account/presentation/pin_flow_controller.dart';

/// Records every value written, in addition to storing it.
class _RecordingStorage extends FlutterSecureStorage {
  final writes = <String, String>{};

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    if (value != null) writes[key] = value;
    return super.write(key: key, value: value);
  }
}

class _FakeAuth extends Fake implements GoTrueClient {
  @override
  User? get currentUser => User(
    id: 'user-a',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
    email: 'qa@example.com',
  );
}

class _FakeClient extends Fake implements SupabaseClient {
  @override
  GoTrueClient get auth => _FakeAuth();
}

/// SC-006 / FR-012: a PIN, its digits and its hash never reach a log line, an
/// exception message, a semantic label, or the network.
void main() {
  const pinA = '483920';
  const pinB = '594031';
  const wrongTries = ['000001', '000002', '000003', '000004', '000005'];

  test('set-up, a wrong try, a correct unlock and an invalidation leave no '
      'trace of the PIN', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final storage = _RecordingStorage();
    final logs = <String>[];
    final messages = <String>[]; // exception messages and results, as text
    final requests = <http.BaseRequest>[];
    final bodies = <String>[];

    final client = MockClient((request) async {
      requests.add(request);
      bodies.add(request.body);
      switch (request.url.path) {
        case '/auth/v1/token':
          return http.Response(
            jsonEncode({
              'access_token': 'temp-access-token',
              'refresh_token': 'temp-refresh-token',
              'token_type': 'bearer',
            }),
            200,
          );
        case '/auth/v1/logout':
          return http.Response('', 204);
      }
      return http.Response('{}', 404);
    });

    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => logs.add(message ?? '');
    addTearDown(() => debugPrint = originalDebugPrint);

    final spec = ZoneSpecification(
      print: (self, parent, zone, line) => logs.add(line),
    );

    await runZoned(() async {
      final auth = AuthRepository(
        _FakeClient(),
        supabaseUrl: 'https://example-ref.supabase.co',
        publishableKey: 'sb_publishable_test_key',
        httpClient: client,
      );
      final pins = SecurePinLockRepository(
        storage: storage,
        userId: () => 'user-a',
        now: () => DateTime.utc(2026, 3, 1, 9),
      );

      // 1. Set-up through the real flow, the real password confirmation over
      //    the fake HTTP client, and the real repository.
      final flow = PinFlowController(
        mode: PinFlowMode.setUp,
        verifyPassword: (password) async {
          final session = await auth.verifyCurrentPassword(password);
          await session.close();
        },
        pins: pins,
      );
      await flow.submitPassword('Secret-123');
      for (final pin in [pinA, pinA]) {
        for (final d in pin.split('')) {
          flow.addDigit(d);
          await pumpEventQueue();
        }
      }
      expect(flow.state.step, PinFlowStep.done);
      messages.add(flow.state.toString());
      flow.dispose();

      // A refused PIN throws a message of its own.
      try {
        await pins.set('123456');
      } on ArgumentError catch (e) {
        messages.add(e.toString());
      }

      // 2. A wrong try, then a correct unlock.
      messages.add((await pins.verify('000001')).toString());
      messages.add((await pins.verify(pinA)).toString());

      // 3. A change, then five wrong tries: the invalidation.
      final change = PinFlowController(
        mode: PinFlowMode.change,
        verifyPassword: (_) async {},
        pins: pins,
      );
      for (final pin in [pinA, pinB, pinB]) {
        for (final d in pin.split('')) {
          change.addDigit(d);
          await pumpEventQueue();
        }
      }
      messages.add(change.state.toString());
      change.dispose();
      for (final pin in wrongTries) {
        messages.add((await pins.verify(pin)).toString());
      }
      expect(await pins.status(), PinStatus.none);
      messages.add(pins.toString());
    }, zoneSpecification: spec);

    final everything = [...logs, ...messages].join('\n');
    final storedRecord = storage.writes['PIN_RECORD_user-a']!;
    final json = jsonDecode(storedRecord) as Map<String, dynamic>;
    final hash = json['hash'] as String;

    for (final pin in [pinA, pinB, ...wrongTries]) {
      expect(everything.contains(pin), isFalse, reason: 'log or message: $pin');
      for (final value in storage.writes.values) {
        expect(value.contains(pin), isFalse, reason: 'stored value: $pin');
      }
    }
    expect(everything.contains(hash), isFalse, reason: 'the hash in a log');

    // The network saw the account password (to confirm it), and nothing of any
    // PIN: not in a URL, a header or a body.
    expect(requests, isNotEmpty);
    expect(bodies.any((b) => b.contains('Secret-123')), isTrue);
    for (final request in requests) {
      final haystack = [
        request.url.toString(),
        request.headers.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
        (request is http.Request) ? request.body : '',
      ].join('\n');
      for (final pin in [pinA, pinB, ...wrongTries]) {
        expect(haystack.contains(pin), isFalse, reason: 'request: $pin');
      }
    }
    // The PIN controller never asked the server anything on its own: only the
    // password confirmation (a sign-in and the closing sign-out) went out.
    expect(requests.map((r) => r.url.path).toSet(), {
      '/auth/v1/token',
      '/auth/v1/logout',
    });
  });
}
