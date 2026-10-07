import 'dart:convert';
import 'dart:typed_data';

import 'package:finance/core/auth/pin_hasher.dart';
import 'package:flutter_test/flutter_test.dart';

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('pbkdf2HmacSha256 known answers', () {
    // RFC 7914 §11: PBKDF2-HMAC-SHA-256, P = "passwd", S = "salt", c = 1,
    // dkLen = 64.
    test('RFC 7914 vector', () {
      final out = pbkdf2HmacSha256(
        ascii.encode('passwd'),
        ascii.encode('salt'),
        iterations: 1,
        length: 64,
      );
      expect(
        _hex(out),
        '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc'
        '49ca9cccf179b645991664b39d77ef317c71b845b1e30bd509112041d3a19783',
      );
    });

    // Widely published PBKDF2-HMAC-SHA-256 vectors for "password" / "salt".
    test('one iteration, 32 bytes', () {
      final out = pbkdf2HmacSha256(
        ascii.encode('password'),
        ascii.encode('salt'),
        iterations: 1,
        length: 32,
      );
      expect(
        _hex(out),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
    });

    test('4096 iterations, 32 bytes', () {
      final out = pbkdf2HmacSha256(
        ascii.encode('password'),
        ascii.encode('salt'),
        iterations: 4096,
        length: 32,
      );
      expect(
        _hex(out),
        'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
      );
    });

    test('a PIN with the production iteration count (reference computed '
        'independently with Python hashlib.pbkdf2_hmac)', () {
      final salt = Uint8List.fromList(List.generate(16, (i) => i));
      expect(
        _hex(derivePinHash('483920', salt)),
        'c72d60e5f166083908f8f678bdfcab82379845e958f297aa4d1bddd0e6b6d9e5',
      );
    });
  });

  group('derivePinHash', () {
    final salt = Uint8List.fromList(List.generate(16, (i) => i + 1));
    final otherSalt = Uint8List.fromList(List.generate(16, (i) => 200 - i));

    test('same PIN and salt always give the same 32 bytes', () {
      final a = derivePinHash('483920', salt);
      final b = derivePinHash('483920', salt);
      expect(a.length, 32);
      expect(a, b);
    });

    test('a different salt gives different bytes', () {
      expect(
        derivePinHash('483920', salt),
        isNot(derivePinHash('483920', otherSalt)),
      );
    });

    test('a different PIN gives different bytes', () {
      expect(
        derivePinHash('483920', salt),
        isNot(derivePinHash('483921', salt)),
      );
    });

    test('the hash never contains the PIN', () {
      final hex = _hex(derivePinHash('483920', salt));
      expect(hex.contains('483920'), isFalse);
    });

    test('derive and verify round trip finishes well inside 250 ms', () {
      final watch = Stopwatch()..start();
      final stored = derivePinHash('483920', salt);
      final candidate = derivePinHash('483920', salt);
      final ok = constantTimeEquals(stored, candidate);
      watch.stop();
      expect(ok, isTrue);
      expect(watch.elapsedMilliseconds, lessThan(250));
    });
  });

  group('randomSalt', () {
    test('16 bytes, different on every call', () {
      final a = randomSalt();
      final b = randomSalt();
      expect(a.length, 16);
      expect(b.length, 16);
      expect(a, isNot(b));
    });
  });

  group('constantTimeEquals', () {
    test('equal lists', () {
      expect(constantTimeEquals([1, 2, 3], [1, 2, 3]), isTrue);
      expect(constantTimeEquals(const [], const []), isTrue);
    });

    test('one byte different at any position', () {
      expect(constantTimeEquals([1, 2, 3], [9, 2, 3]), isFalse);
      expect(constantTimeEquals([1, 2, 3], [1, 2, 9]), isFalse);
    });

    test('different lengths', () {
      expect(constantTimeEquals([1, 2, 3], [1, 2]), isFalse);
      expect(constantTimeEquals([1, 2], [1, 2, 3]), isFalse);
    });
  });
}
