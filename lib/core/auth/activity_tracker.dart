import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import 'app_lock_policy.dart';
import 'lock_channel.dart';

/// Locks the app after [AppLockPolicy.inactivityPeriod] without interaction
/// (FR-001) and, on the web, shares the timer and the lock across browser tabs
/// (FR-001a). See `contracts/inactivity-lock.md`.
///
/// The decision is made from timestamps, not from counting timer ticks: a
/// browser may throttle or stop a hidden tab's timers, so the periodic check is
/// best-effort and [onResumed] is what makes sure the first thing a person sees
/// after coming back is the lock.
///
/// It never reads or writes financial data, never touches sync, and never logs.
class ActivityTracker {
  ActivityTracker({
    required DateTime Function() now,
    required bool Function() isSignedIn,
    required bool Function() isLocked,
    required void Function() lock,
    required void Function() unlock,
    required LockChannel channel,
    Duration? period,
    this.checkInterval = const Duration(seconds: 10),
    this.broadcastInterval = const Duration(seconds: 5),
  }) : _now = now,
       _isSignedIn = isSignedIn,
       _isLocked = isLocked,
       _lock = lock,
       _unlock = unlock,
       _channel = channel,
       _period = period ?? AppLockPolicy.inactivityPeriod {
    _lastActivityAt = _now();
    _subscription = _channel.messages.listen(_onRemote);
  }

  final DateTime Function() _now;
  final bool Function() _isSignedIn;
  final bool Function() _isLocked;
  final void Function() _lock;
  final void Function() _unlock;
  final LockChannel _channel;
  final Duration _period;

  /// How often the periodic check runs while signed in.
  final Duration checkInterval;

  /// At most one `activity` message per this long (a mouse drag is hundreds of
  /// events per second).
  final Duration broadcastInterval;

  late DateTime _lastActivityAt;
  DateTime? _lastBroadcastAt;
  Timer? _timer;
  StreamSubscription<LockMessage>? _subscription;
  bool _applyingRemote = false;
  bool _hooksAttached = false;

  /// The last interaction seen by this window or reported by another.
  DateTime get lastActivityAt => _lastActivityAt;

  /// Hooks the framework's global pointer router and hardware keyboard, which
  /// see every event whichever widget handles it, on every platform.
  void attachSystemHooks() {
    if (_hooksAttached) return;
    _hooksAttached = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(onPointerEvent);
    HardwareKeyboard.instance.addHandler(onKeyEvent);
  }

  /// Only a person at the device produces these: a press, a release, a scroll
  /// or a move with a button or finger down. A mouse merely passing over the
  /// window ([PointerHoverEvent]) is not use.
  void onPointerEvent(PointerEvent event) {
    if (event is PointerDownEvent ||
        event is PointerUpEvent ||
        event is PointerMoveEvent ||
        event is PointerSignalEvent) {
      recordInteraction();
    }
  }

  /// Always returns `false`: the tracker watches keys, it never consumes them.
  bool onKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) recordInteraction();
    return false;
  }

  /// Notes an interaction now, and tells the other windows at most once per
  /// [broadcastInterval].
  void recordInteraction() {
    final now = _now();
    _lastActivityAt = now;
    final last = _lastBroadcastAt;
    if (last == null || now.difference(last) >= broadcastInterval) {
      _lastBroadcastAt = now;
      _channel.send(
        LockMessage(
          type: LockMessageType.activity,
          from: _channel.windowId,
          at: now.millisecondsSinceEpoch,
        ),
      );
    }
  }

  /// Starts or stops the periodic check as the person signs in or out; while
  /// signed out nothing is armed.
  void onSignedInChanged(bool signedIn) {
    _timer?.cancel();
    _timer = null;
    if (!signedIn) return;
    _lastActivityAt = _now();
    _timer = Timer.periodic(checkInterval, (_) => check());
  }

  /// The app lock changed for any reason. Only a transition to unlocked matters
  /// here: it restarts the period and tells the other windows. A transition to
  /// locked needs no message: this window's own decision already sent `lock`,
  /// and a window that merely starts locked must stay silent so that opening a
  /// tab never locks a tab that is in use.
  void onLockChanged(bool locked) {
    if (_applyingRemote || locked) return;
    _lastActivityAt = _now();
    _channel.send(
      LockMessage(type: LockMessageType.unlock, from: _channel.windowId),
    );
  }

  /// The app came back to the front (a tab became visible, the phone app
  /// resumed): decide now, without waiting for the next periodic check.
  void onResumed() => check();

  /// Locks the app if nobody has used it for the whole period.
  void check() {
    if (!AppLockPolicy.shouldLock(
      lastActivityAt: _lastActivityAt,
      now: _now(),
      isSignedIn: _isSignedIn(),
      isLocked: _isLocked(),
      period: _period,
    )) {
      return;
    }
    _lock();
    _channel.send(
      LockMessage(type: LockMessageType.lock, from: _channel.windowId),
    );
  }

  void _onRemote(LockMessage message) {
    switch (message.type) {
      case LockMessageType.activity:
        final at = message.at;
        if (at == null) return;
        final reported = DateTime.fromMillisecondsSinceEpoch(at);
        if (reported.isAfter(_lastActivityAt)) _lastActivityAt = reported;
      case LockMessageType.lock:
        if (_isSignedIn() && !_isLocked()) _applyRemote(_lock);
      case LockMessageType.unlock:
        if (_isLocked()) {
          _applyRemote(_unlock);
          _lastActivityAt = _now();
        }
    }
  }

  /// Runs a state change that came from another window without echoing it back.
  void _applyRemote(void Function() change) {
    _applyingRemote = true;
    try {
      change();
    } finally {
      _applyingRemote = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    if (_hooksAttached) {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(onPointerEvent);
      HardwareKeyboard.instance.removeHandler(onKeyEvent);
      _hooksAttached = false;
    }
    _channel.close();
  }
}
