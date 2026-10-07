import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/auth/lock_channel.dart';

/// The wire format between browser tabs (`contracts/inactivity-lock.md` §4).
void main() {
  group('encode / decode', () {
    test('activity keeps its time', () {
      const message = LockMessage(
        type: LockMessageType.activity,
        from: 'a',
        at: 1790000000000,
      );
      final decoded = LockMessage.decode(message.encode());
      expect(decoded?.type, LockMessageType.activity);
      expect(decoded?.at, 1790000000000);
      expect(decoded?.from, 'a');
    });

    test('lock and unlock round-trip', () {
      for (final type in [LockMessageType.lock, LockMessageType.unlock]) {
        final decoded = LockMessage.decode(
          LockMessage(type: type, from: 'b').encode(),
        );
        expect(decoded?.type, type);
        expect(decoded?.at, isNull);
      }
    });

    test('the format is versioned and carries no account data', () {
      final json = const LockMessage(
        type: LockMessageType.lock,
        from: 'w1',
      ).encode();
      expect(json, contains('"v":1'));
      expect(json, isNot(contains('user')));
      expect(json, isNot(contains('email')));
    });
  });

  group('what is ignored', () {
    test('an unknown version', () {
      expect(LockMessage.decode('{"v":2,"type":"lock","from":"a"}'), isNull);
    });

    test('an unknown type', () {
      expect(LockMessage.decode('{"v":1,"type":"explode","from":"a"}'), isNull);
    });

    test('malformed JSON, a non-string, and a missing sender', () {
      expect(LockMessage.decode('not json'), isNull);
      expect(LockMessage.decode(42), isNull);
      expect(LockMessage.decode(null), isNull);
      expect(LockMessage.decode('{"v":1,"type":"lock"}'), isNull);
      expect(LockMessage.decode('[1,2]'), isNull);
    });

    test("a window's own message", () {
      final raw = const LockMessage(
        type: LockMessageType.unlock,
        from: 'me',
      ).encode();
      expect(LockMessage.decode(raw, ownId: 'me'), isNull);
      expect(LockMessage.decode(raw, ownId: 'someone-else'), isNotNull);
    });
  });

  test('a window id is 16 hex characters and differs per window', () {
    final a = newWindowId();
    final b = newWindowId();
    expect(a, matches(RegExp(r'^[0-9a-f]{16}$')));
    expect(a, isNot(b));
  });
}
