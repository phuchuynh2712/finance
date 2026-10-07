import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Iterations of the PBKDF2 used for a stored PIN.
const int pinHashIterations = 10000;

/// PBKDF2 with HMAC-SHA-256 (RFC 8018), built on `package:crypto`'s [Hmac].
///
/// A six-digit PIN has only a million values, so no hash makes it safe against
/// someone who can read the stored record; the protection is the attempt limit
/// and the platform's secure storage. The salted, iterated hash is there so
/// the record never contains the PIN and cannot be read back (FR-012).
Uint8List pbkdf2HmacSha256(
  List<int> password,
  List<int> salt, {
  required int iterations,
  required int length,
}) {
  final hmac = Hmac(sha256, password);
  const blockSize = 32; // SHA-256 output
  final blocks = (length + blockSize - 1) ~/ blockSize;
  final out = BytesBuilder();
  for (var block = 1; block <= blocks; block++) {
    final counter = Uint8List(4)
      ..buffer.asByteData().setUint32(0, block, Endian.big);
    var u = hmac.convert([...salt, ...counter]).bytes;
    final t = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    out.add(t);
  }
  return Uint8List.fromList(out.toBytes().sublist(0, length));
}

/// The 32 bytes stored for [pin] with [salt].
Uint8List derivePinHash(
  String pin,
  List<int> salt, {
  int iterations = pinHashIterations,
}) => pbkdf2HmacSha256(pin.codeUnits, salt, iterations: iterations, length: 32);

/// 16 random bytes from the platform's secure generator.
Uint8List randomSalt() {
  final random = Random.secure();
  return Uint8List.fromList(List.generate(16, (_) => random.nextInt(256)));
}

/// Compares in time that does not depend on where the first difference is.
bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
