import 'dart:async';

import 'package:finance/core/auth/lock_channel.dart';

/// Connected in-memory [LockChannel]s: a message sent by one is delivered
/// synchronously to every other one, never to itself, and recorded.
class FakeLockChannelHub {
  final List<FakeLockChannel> _channels = [];

  FakeLockChannel create([String? id]) {
    final channel = FakeLockChannel._(this, id ?? 'window-${_channels.length}');
    _channels.add(channel);
    return channel;
  }

  void _deliver(FakeLockChannel from, LockMessage message) {
    for (final channel in _channels) {
      if (!identical(channel, from) && !channel._closed) {
        channel._controller.add(message);
      }
    }
  }
}

class FakeLockChannel implements LockChannel {
  FakeLockChannel._(this._hub, this.windowId);

  final FakeLockChannelHub _hub;
  final StreamController<LockMessage> _controller =
      StreamController<LockMessage>.broadcast(sync: true);
  bool _closed = false;

  @override
  final String windowId;

  /// Everything this window has sent, in order.
  final List<LockMessage> sent = [];

  Iterable<LockMessage> sentOfType(LockMessageType type) =>
      sent.where((m) => m.type == type);

  @override
  Stream<LockMessage> get messages => _controller.stream;

  @override
  void send(LockMessage message) {
    sent.add(message);
    _hub._deliver(this, message);
  }

  @override
  void close() {
    _closed = true;
    unawaited(_controller.close());
  }
}
