import 'lock_channel.dart';

/// The channel of every platform that has exactly one window: it hears
/// nothing and says nothing.
LockChannel createLockChannel() => _SingleWindowLockChannel();

class _SingleWindowLockChannel implements LockChannel {
  @override
  final String windowId = newWindowId();

  @override
  Stream<LockMessage> get messages => const Stream<LockMessage>.empty();

  @override
  void send(LockMessage message) {}

  @override
  void close() {}
}
