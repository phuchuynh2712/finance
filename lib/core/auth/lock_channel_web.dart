import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'lock_channel.dart';

/// The browser's `BroadcastChannel` between the tabs of this origin, which is
/// delivered to hidden tabs too and needs no polling.
LockChannel createLockChannel() => _BroadcastLockChannel();

class _BroadcastLockChannel implements LockChannel {
  _BroadcastLockChannel() {
    _channel.onmessage = ((web.MessageEvent event) {
      final message = LockMessage.decode(event.data.dartify(), ownId: windowId);
      if (message != null) _controller.add(message);
    }).toJS;
  }

  @override
  final String windowId = newWindowId();

  final web.BroadcastChannel _channel = web.BroadcastChannel(
    'finance-app-lock',
  );
  final StreamController<LockMessage> _controller =
      StreamController<LockMessage>.broadcast();

  @override
  Stream<LockMessage> get messages => _controller.stream;

  @override
  void send(LockMessage message) {
    _channel.postMessage(message.encode().toJS);
  }

  @override
  void close() {
    _channel.close();
    unawaited(_controller.close());
  }
}
