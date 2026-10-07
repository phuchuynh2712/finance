import 'dart:convert';

import 'package:finance/core/auth/pin_lock_repository.dart';
import 'package:finance/core/auth/pin_rules.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// A storage whose `write` throws once [failWritesAfter] writes have been made.
class _FlakyStorage extends FlutterSecureStorage {
  _FlakyStorage({this.failWritesAfter});

  final int? failWritesAfter;
  int writes = 0;

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
  }) async {
    final limit = failWritesAfter;
    if (limit != null && writes >= limit) {
      throw StateError('storage unavailable');
    }
    writes++;
    return super.write(key: key, value: value);
  }
}

const _storage = FlutterSecureStorage();

void main() {
  late DateTime now;
  String? userId;

  PinLockRepository create({FlutterSecureStorage storage = _storage}) =>
      SecurePinLockRepository(
        storage: storage,
        userId: () => userId,
        now: () => now,
      );

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    now = DateTime.utc(2026, 3, 1, 9);
    userId = 'user-a';
  });

  group('status', () {
    test('none when no PIN was ever set', () async {
      expect(await create().status(), PinStatus.none);
      expect(await create().triesLeft(), maxWrongTries);
    });

    test('active after set, expired after exactly 365 days', () async {
      final repo = create();
      await repo.set('483920');
      expect(await repo.status(), PinStatus.active);

      now = now.add(const Duration(days: 364));
      expect(await repo.status(), PinStatus.active);

      now = DateTime.utc(2026, 3, 1, 9).add(const Duration(days: 365));
      expect(await repo.status(), PinStatus.expired);
    });

    test('none with no signed-in account; writes are no-ops', () async {
      final repo = create();
      await repo.set('483920');
      userId = null;
      expect(await repo.status(), PinStatus.none);
      await repo.set('594031');
      await repo.clear();
      await repo.markOfferShown();
      userId = 'user-a';
      expect(await repo.status(), PinStatus.active);
      expect(await repo.shouldOfferPin(), isTrue);
    });

    test('a tampered or unparsable record reads as none', () async {
      for (final value in [
        'not json',
        '[]',
        '{}',
        '{"v":2,"salt":"AAAA","hash":"AAAA","iterations":10000,"setAt":"2026-03-01T09:00:00Z"}',
        '{"v":1,"salt":"%%%","hash":"AAAA","iterations":10000,"setAt":"2026-03-01T09:00:00Z"}',
        '{"v":1,"salt":"AAAA","hash":"AAAA","iterations":0,"setAt":"2026-03-01T09:00:00Z"}',
        '{"v":1,"salt":"AAAA","hash":"AAAA","iterations":10000,"setAt":"yesterday"}',
      ]) {
        FlutterSecureStorage.setMockInitialValues({'PIN_RECORD_user-a': value});
        expect(await create().status(), PinStatus.none, reason: value);
        expect(await create().verify('483920'), const PinCheckUnavailable());
      }
    });
  });

  group('set', () {
    test('refuses a PIN the rules refuse', () async {
      final repo = create();
      await expectLater(repo.set('1234'), throwsArgumentError);
      await expectLater(repo.set('111111'), throwsArgumentError);
      expect(await repo.status(), PinStatus.none);
    });

    test('writes a versioned record that never contains the PIN', () async {
      await create().set('483920');
      final raw = await _storage.read(key: 'PIN_RECORD_user-a');
      final json = jsonDecode(raw!) as Map<String, Object?>;
      expect(json['v'], 1);
      expect(json['iterations'], 10000);
      expect(base64Decode(json['salt']! as String), hasLength(16));
      expect(base64Decode(json['hash']! as String), hasLength(32));
      expect(DateTime.parse(json['setAt']! as String).isUtc, isTrue);
      expect(raw.contains('483920'), isFalse);
    });

    test(
      'replaces the whole record and resets the wrong-tries count',
      () async {
        final repo = create();
        await repo.set('483920');
        await repo.verify('000001');
        await repo.verify('000002');
        expect(await repo.triesLeft(), 3);

        await repo.set('594031');
        expect(await repo.triesLeft(), maxWrongTries);
        expect(await repo.verify('483920'), const PinCheckWrong(4));
        expect(await repo.verify('594031'), const PinCheckSuccess());
      },
    );

    test('two sets with the same PIN use different salts', () async {
      final repo = create();
      await repo.set('483920');
      final first = await _storage.read(key: 'PIN_RECORD_user-a');
      await repo.set('483920');
      final second = await _storage.read(key: 'PIN_RECORD_user-a');
      expect(first, isNot(second));
    });
  });

  group('verify', () {
    test('success on the right PIN', () async {
      final repo = create();
      await repo.set('483920');
      expect(await repo.verify('483920'), const PinCheckSuccess());
    });

    test('wrong counts down 4, 3, 2, 1 and the fifth invalidates', () async {
      final repo = create();
      await repo.set('483920');
      expect(await repo.verify('000001'), const PinCheckWrong(4));
      expect(await repo.verify('000002'), const PinCheckWrong(3));
      expect(await repo.verify('000003'), const PinCheckWrong(2));
      expect(await repo.verify('000004'), const PinCheckWrong(1));
      expect(await repo.verify('000005'), const PinCheckInvalidated());

      expect(await repo.status(), PinStatus.none);
      expect(await _storage.read(key: 'PIN_RECORD_user-a'), isNull);
      expect(await _storage.read(key: 'PIN_FAILS_user-a'), isNull);
      expect(await repo.verify('483920'), const PinCheckUnavailable());
    });

    test('the right PIN on the fifth try is still a success', () async {
      final repo = create();
      await repo.set('483920');
      for (var i = 1; i <= 4; i++) {
        await repo.verify('00000$i');
      }
      expect(await repo.verify('483920'), const PinCheckSuccess());
      expect(await repo.status(), PinStatus.active);
    });

    test('success resets the count', () async {
      final repo = create();
      await repo.set('483920');
      await repo.verify('000001');
      await repo.verify('000002');
      expect(await repo.triesLeft(), 3);
      expect(await repo.verify('483920'), const PinCheckSuccess());
      expect(await repo.triesLeft(), maxWrongTries);
      expect(await _storage.read(key: 'PIN_FAILS_user-a'), isNull);
    });

    test('the count survives a new repository instance (a restart)', () async {
      await create().set('483920');
      await create().verify('000001');
      await create().verify('000002');
      expect(await create().triesLeft(), 3);
      expect(await create().verify('000003'), const PinCheckWrong(2));
    });

    test(
      'a stored count already at five invalidates without comparing',
      () async {
        final repo = create();
        await repo.set('483920');
        await _storage.write(key: 'PIN_FAILS_user-a', value: '5');
        // Even the right PIN does not get through.
        expect(await repo.verify('483920'), const PinCheckInvalidated());
        expect(await repo.status(), PinStatus.none);
      },
    );

    test('unavailable when none or expired', () async {
      final repo = create();
      expect(await repo.verify('483920'), const PinCheckUnavailable());
      await repo.set('483920');
      now = now.add(pinValidity);
      expect(await repo.verify('483920'), const PinCheckUnavailable());
    });

    test('unavailable with no signed-in account', () async {
      final repo = create();
      await repo.set('483920');
      userId = null;
      expect(await repo.verify('483920'), const PinCheckUnavailable());
    });

    test('the count is written before the comparison', () async {
      // verify() makes exactly one write before it can compare: the count. If
      // the storage fails on any further write, that count is already stored.
      final seed = create();
      await seed.set('483920');
      final flaky = _FlakyStorage(failWritesAfter: 1);
      final repo = create(storage: flaky);
      // The very first write is the count; the second (a reset) would fail,
      // but a wrong PIN needs no second write.
      expect(await repo.verify('000001'), const PinCheckWrong(4));
      expect(await _storage.read(key: 'PIN_FAILS_user-a'), '1');
    });

    test('a storage failure while counting surfaces, never unlocks', () async {
      await create().set('483920');
      final repo = create(storage: _FlakyStorage(failWritesAfter: 0));
      await expectLater(repo.verify('483920'), throwsStateError);
      // The right PIN was not accepted without the count being recorded.
    });
  });

  group('accounts', () {
    test('two accounts on one device never see each other', () async {
      final repo = create();
      await repo.set('483920');
      await repo.verify('000001');
      await repo.markOfferShown();

      userId = 'user-b';
      expect(await repo.status(), PinStatus.none);
      expect(await repo.triesLeft(), maxWrongTries);
      expect(await repo.shouldOfferPin(), isTrue);
      expect(await repo.verify('483920'), const PinCheckUnavailable());

      await repo.set('594031');
      userId = 'user-a';
      expect(await repo.triesLeft(), 4);
      expect(await repo.verify('594031'), const PinCheckWrong(3));
      expect(await repo.verify('483920'), const PinCheckSuccess());
    });
  });

  group('clear and the offer marker', () {
    test('clear deletes the record and the count, keeps the marker', () async {
      final repo = create();
      await repo.set('483920');
      await repo.verify('000001');
      await repo.markOfferShown();

      await repo.clear();
      expect(await repo.status(), PinStatus.none);
      expect(await repo.triesLeft(), maxWrongTries);
      expect(await _storage.read(key: 'PIN_RECORD_user-a'), isNull);
      expect(await _storage.read(key: 'PIN_FAILS_user-a'), isNull);
      expect(await repo.shouldOfferPin(), isFalse);
    });

    test('shouldOfferPin is true until the marker is written', () async {
      final repo = create();
      expect(await repo.shouldOfferPin(), isTrue);
      await repo.markOfferShown();
      expect(await repo.shouldOfferPin(), isFalse);
      expect(await _storage.read(key: 'PIN_OFFER_SHOWN_user-a'), 'true');
    });
  });

  group('the PIN never leaks', () {
    test('no stored value, result string or error contains it', () async {
      final repo = create();
      await repo.set('483920');
      final results = <Object>[
        await repo.verify('594031'),
        await repo.verify('483920'),
      ];
      final everything = StringBuffer();
      everything.writeAll(results.map((r) => r.toString()));
      for (final key in [
        'PIN_RECORD_user-a',
        'PIN_FAILS_user-a',
        'PIN_OFFER_SHOWN_user-a',
      ]) {
        everything.write(await _storage.read(key: key));
      }
      everything.write(repo.toString());
      final text = everything.toString();
      for (final pin in ['483920', '594031']) {
        expect(text.contains(pin), isFalse, reason: pin);
      }
      try {
        await repo.set('123');
      } on ArgumentError catch (e) {
        expect(e.toString().contains('123'), isFalse);
      }
    });
  });
}
