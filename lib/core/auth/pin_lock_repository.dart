import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'pin_hasher.dart';
import 'pin_rules.dart';

/// Whether the signed-in account has a PIN on this device, and if it still
/// counts.
enum PinStatus {
  /// No PIN, or one that cannot be read.
  none,

  /// A PIN that may unlock the app.
  active,

  /// A PIN older than [pinValidity]: it no longer unlocks, the password does.
  expired,
}

/// What [PinLockRepository.verify] found.
sealed class PinCheckResult {
  const PinCheckResult();
}

/// The PIN was right.
final class PinCheckSuccess extends PinCheckResult {
  const PinCheckSuccess();

  @override
  bool operator ==(Object other) => other is PinCheckSuccess;

  @override
  int get hashCode => 1;

  @override
  String toString() => 'PinCheckSuccess';
}

/// The PIN was wrong; [triesLeft] more wrong tries are allowed (1 to 4).
final class PinCheckWrong extends PinCheckResult {
  const PinCheckWrong(this.triesLeft);

  final int triesLeft;

  @override
  bool operator ==(Object other) =>
      other is PinCheckWrong && other.triesLeft == triesLeft;

  @override
  int get hashCode => Object.hash(2, triesLeft);

  @override
  String toString() => 'PinCheckWrong($triesLeft)';
}

/// The fifth wrong try (or an already used-up count): the PIN and the count
/// are deleted and only the password can unlock the app.
final class PinCheckInvalidated extends PinCheckResult {
  const PinCheckInvalidated();

  @override
  bool operator ==(Object other) => other is PinCheckInvalidated;

  @override
  int get hashCode => 3;

  @override
  String toString() => 'PinCheckInvalidated';
}

/// There is no active PIN to check: none, expired, or nobody is signed in.
final class PinCheckUnavailable extends PinCheckResult {
  const PinCheckUnavailable();

  @override
  bool operator ==(Object other) => other is PinCheckUnavailable;

  @override
  int get hashCode => 4;

  @override
  String toString() => 'PinCheckUnavailable';
}

/// The PIN of the signed-in account on this device (FR-006…FR-019), kept only
/// in the platform's secure storage as a salted, iterated hash. It never
/// makes a network call and never writes the PIN, a digit of it or a prefix
/// anywhere. See `contracts/pin-lock-repository.md`.
abstract interface class PinLockRepository {
  Future<PinStatus> status();

  /// [maxWrongTries] minus the stored wrong tries.
  Future<int> triesLeft();

  /// Stores [pin] as the new PIN (replacing any record and the count). Throws
  /// [ArgumentError] when `pin_rules.validate` refuses it.
  Future<void> set(String pin);

  /// The only place a PIN is compared.
  Future<PinCheckResult> verify(String pin);

  /// Deletes the record and the count; the one-time offer marker is kept.
  Future<void> clear();

  /// `true` until [markOfferShown] was called for this account on this device.
  Future<bool> shouldOfferPin();

  Future<void> markOfferShown();
}

/// [PinLockRepository] over `flutter_secure_storage`.
///
/// Keys (`data-model.md` §1.3–§1.5), all scoped by the signed-in user's id so
/// two accounts on one device never see each other's PIN:
/// `PIN_RECORD_<id>`, `PIN_FAILS_<id>`, `PIN_OFFER_SHOWN_<id>`.
class SecurePinLockRepository implements PinLockRepository {
  SecurePinLockRepository({
    required FlutterSecureStorage storage,
    required String? Function() userId,
    DateTime Function()? now,
  }) : _storage = storage,
       _userId = userId,
       _now = now ?? DateTime.now;

  static const _recordKeyPrefix = 'PIN_RECORD_';
  static const _failsKeyPrefix = 'PIN_FAILS_';
  static const _offerKeyPrefix = 'PIN_OFFER_SHOWN_';
  static const _formatVersion = 1;

  final FlutterSecureStorage _storage;
  final String? Function() _userId;
  final DateTime Function() _now;

  @override
  Future<PinStatus> status() async {
    final record = await _readRecord();
    if (record == null) return PinStatus.none;
    return isExpired(record.setAt, _now())
        ? PinStatus.expired
        : PinStatus.active;
  }

  @override
  Future<int> triesLeft() async {
    final id = _userId();
    if (id == null) return maxWrongTries;
    final left = maxWrongTries - await _readFails(id);
    return left < 0 ? 0 : left;
  }

  @override
  Future<void> set(String pin) async {
    // Never put the PIN in the message: it would end up in a log line.
    if (validate(pin) != null) {
      throw ArgumentError('The PIN does not meet the rules');
    }
    final id = _userId();
    if (id == null) return;
    final salt = randomSalt();
    final hash = derivePinHash(pin, salt);
    final record = jsonEncode({
      'v': _formatVersion,
      'salt': base64Encode(salt),
      'hash': base64Encode(hash),
      'iterations': pinHashIterations,
      'setAt': _now().toUtc().toIso8601String(),
    });
    await _storage.write(key: '$_recordKeyPrefix$id', value: record);
    await _storage.delete(key: '$_failsKeyPrefix$id');
  }

  @override
  Future<PinCheckResult> verify(String pin) async {
    final id = _userId();
    final record = await _readRecord();
    if (id == null || record == null || isExpired(record.setAt, _now())) {
      return const PinCheckUnavailable();
    }
    final fails = await _readFails(id);
    if (fails >= maxWrongTries) {
      await _deleteAll(id);
      return const PinCheckInvalidated();
    }
    // Count the try first: ending the process during the comparison must not
    // give a free attempt.
    final failsNow = fails + 1;
    await _storage.write(key: '$_failsKeyPrefix$id', value: '$failsNow');

    final candidate = derivePinHash(
      pin,
      record.salt,
      iterations: record.iterations,
    );
    if (constantTimeEquals(candidate, record.hash)) {
      await _storage.delete(key: '$_failsKeyPrefix$id');
      return const PinCheckSuccess();
    }
    if (failsNow >= maxWrongTries) {
      await _deleteAll(id);
      return const PinCheckInvalidated();
    }
    return PinCheckWrong(maxWrongTries - failsNow);
  }

  @override
  Future<void> clear() async {
    final id = _userId();
    if (id == null) return;
    await _deleteAll(id);
  }

  @override
  Future<bool> shouldOfferPin() async {
    final id = _userId();
    if (id == null) return false;
    return !await _storage.containsKey(key: '$_offerKeyPrefix$id');
  }

  @override
  Future<void> markOfferShown() async {
    final id = _userId();
    if (id == null) return;
    await _storage.write(key: '$_offerKeyPrefix$id', value: 'true');
  }

  @override
  String toString() => 'SecurePinLockRepository';

  Future<void> _deleteAll(String id) async {
    await _storage.delete(key: '$_recordKeyPrefix$id');
    await _storage.delete(key: '$_failsKeyPrefix$id');
  }

  Future<int> _readFails(String id) async {
    final raw = await _storage.read(key: '$_failsKeyPrefix$id');
    return int.tryParse(raw ?? '') ?? 0;
  }

  /// `null` for no account, no record, or a record that cannot be trusted.
  Future<_PinRecord?> _readRecord() async {
    final id = _userId();
    if (id == null) return null;
    final raw = await _storage.read(key: '$_recordKeyPrefix$id');
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, Object?> || json['v'] != _formatVersion) {
        return null;
      }
      final salt = base64Decode(json['salt']! as String);
      final hash = base64Decode(json['hash']! as String);
      final iterations = json['iterations'];
      final setAt = DateTime.tryParse(json['setAt']! as String);
      if (salt.length != 16 ||
          hash.length != 32 ||
          iterations is! int ||
          iterations < 1 ||
          setAt == null) {
        return null;
      }
      return _PinRecord(salt, hash, iterations, setAt);
    } on Object {
      // Anything unparsable (including a wrong field type) counts as no PIN.
      return null;
    }
  }
}

class _PinRecord {
  const _PinRecord(this.salt, this.hash, this.iterations, this.setAt);

  final Uint8List salt;
  final Uint8List hash;
  final int iterations;
  final DateTime setAt;
}
