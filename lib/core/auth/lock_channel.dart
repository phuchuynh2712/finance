import 'dart:convert';
import 'dart:math';

export 'lock_channel_stub.dart'
    if (dart.library.js_interop) 'lock_channel_web.dart'
    show createLockChannel;

/// What one window of the app tells the others (web only; see [LockChannel]).
enum LockMessageType {
  /// The sender saw an interaction at [LockMessage.at].
  activity,

  /// The sender locked the app because of inactivity or a resume check.
  /// Never sent for a window that merely starts locked (a page load).
  lock,

  /// The sender unlocked the app after a successful authentication.
  unlock,
}

/// A versioned, account-free message between windows of the app
/// (`contracts/inactivity-lock.md` §4).
class LockMessage {
  const LockMessage({required this.type, required this.from, this.at});

  final LockMessageType type;

  /// The sending window's id, so a window can ignore its own messages.
  final String from;

  /// Epoch milliseconds of the interaction; only for [LockMessageType.activity].
  final int? at;

  static const int version = 1;

  String encode() =>
      jsonEncode({'v': version, 'type': type.name, 'at': at, 'from': from});

  /// `null` for anything that is not a version-[version] message of a known
  /// type, and for the receiver's own messages ([ownId]).
  static LockMessage? decode(Object? raw, {String? ownId}) {
    if (raw is! String) return null;
    final Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (json is! Map<String, Object?> || json['v'] != version) return null;
    final typeName = json['type'];
    final from = json['from'];
    if (typeName is! String || from is! String) return null;
    final type = LockMessageType.values.asNameMap()[typeName];
    if (type == null || from == ownId) return null;
    final at = json['at'];
    return LockMessage(type: type, from: from, at: at is int ? at : null);
  }
}

/// Carries [LockMessage]s between the windows (browser tabs) of the web app.
/// Every other platform has one window, so its channel does nothing.
abstract interface class LockChannel {
  /// This window's id (stamped on everything it sends).
  String get windowId;

  /// Messages from the **other** windows only.
  Stream<LockMessage> get messages;

  void send(LockMessage message);

  void close();
}

/// A random id for one window: 16 hex characters.
String newWindowId() {
  final random = Random.secure();
  return List.generate(
    8,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
