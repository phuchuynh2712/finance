import 'package:fake_async/fake_async.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;

import 'package:finance/core/auth/activity_tracker.dart';
import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/auth/lock_channel.dart';
import 'package:finance/core/sync/pull_service.dart';
import 'package:finance/core/sync/pull_service_provider.dart';
import 'package:finance/core/sync/sync_worker.dart';
import 'package:finance/core/sync/sync_worker_provider.dart';

import '../../../support/fake_lock_channel.dart';

final _start = DateTime(2026, 10, 7, 12);

/// One window of the app: a tracker wired to plain flags instead of Riverpod,
/// on the fake clock of [async]. `lock` / `unlock` behave like the provider's
/// listener does (they tell the tracker the lock changed).
class _Window {
  _Window(
    this.async,
    this.channel, {
    this.signedIn = true,
    this.locked = false,
    Duration checkInterval = const Duration(seconds: 10),
  }) {
    tracker = ActivityTracker(
      now: () => _start.add(async.elapsed),
      isSignedIn: () => signedIn,
      isLocked: () => locked,
      lock: () {
        locked = true;
        lockCalls++;
        tracker.onLockChanged(true);
      },
      unlock: () {
        locked = false;
        unlockCalls++;
        tracker.onLockChanged(false);
      },
      channel: channel,
      checkInterval: checkInterval,
    );
    tracker.onSignedInChanged(signedIn);
    // A window that starts locked is told so, like the provider listener does.
    if (locked) tracker.onLockChanged(true);
  }

  final FakeAsync async;
  final FakeLockChannel channel;
  bool signedIn;
  bool locked;
  int lockCalls = 0;
  int unlockCalls = 0;
  late final ActivityTracker tracker;

  /// A person unlocking with the password (or biometric): not a remote change.
  void unlockLocally() {
    locked = false;
    tracker.onLockChanged(false);
  }
}

KeyDownEvent _keyDown() => const KeyDownEvent(
  physicalKey: PhysicalKeyboardKey.keyA,
  logicalKey: LogicalKeyboardKey.keyA,
  timeStamp: Duration.zero,
);

class _FakeSyncWorker extends Fake implements SyncWorker {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const fiveMinutes = Duration(minutes: 5);

  group('the period', () {
    test('(a) no interaction for 5 minutes → locked once', () {
      fakeAsync((async) {
        final w = _Window(async, FakeLockChannelHub().create());
        async.elapse(const Duration(minutes: 4, seconds: 50));
        expect(w.locked, isFalse);
        async.elapse(const Duration(seconds: 20));
        expect(w.locked, isTrue);
        expect(w.lockCalls, 1);
        async.elapse(const Duration(hours: 1));
        expect(w.lockCalls, 1, reason: '(f) already locked: no repeated lock');
      });
    });

    test('(b) an interaction every 4 minutes for 20 minutes → never', () {
      fakeAsync((async) {
        final w = _Window(async, FakeLockChannelHub().create());
        for (var i = 0; i < 5; i++) {
          async.elapse(const Duration(minutes: 4));
          w.tracker.recordInteraction();
        }
        expect(w.locked, isFalse);
        expect(w.lockCalls, 0);
      });
    });
  });

  group('(c) what counts as an interaction', () {
    final counted = <String, void Function(ActivityTracker)>{
      'pointer down': (t) => t.onPointerEvent(const PointerDownEvent()),
      'pointer up': (t) => t.onPointerEvent(const PointerUpEvent()),
      'a move with a button or finger down': (t) =>
          t.onPointerEvent(const PointerMoveEvent()),
      'a scroll': (t) => t.onPointerEvent(const PointerScrollEvent()),
      'a key down': (t) => t.onKeyEvent(_keyDown()),
    };
    for (final entry in counted.entries) {
      test('${entry.key} resets the period', () {
        fakeAsync((async) {
          final w = _Window(async, FakeLockChannelHub().create());
          async.elapse(const Duration(minutes: 4));
          entry.value(w.tracker);
          async.elapse(const Duration(minutes: 4));
          expect(w.locked, isFalse, reason: '8 minutes, but one use at 4');
        });
      });
    }

    test('a mouse only hovering does not', () {
      fakeAsync((async) {
        final w = _Window(async, FakeLockChannelHub().create());
        for (var i = 0; i < 6; i++) {
          async.elapse(const Duration(minutes: 1));
          w.tracker.onPointerEvent(const PointerHoverEvent());
        }
        expect(w.locked, isTrue);
      });
    });

    test('the key handler never consumes the key', () {
      fakeAsync((async) {
        final w = _Window(async, FakeLockChannelHub().create());
        expect(w.tracker.onKeyEvent(_keyDown()), isFalse);
      });
    });
  });

  test(
    '(d) resumed after 5+ minutes locks at once, without the next check',
    () {
      fakeAsync((async) {
        final w = _Window(
          async,
          FakeLockChannelHub().create(),
          checkInterval: const Duration(hours: 1),
        );
        async.elapse(const Duration(minutes: 6));
        expect(w.locked, isFalse, reason: 'the periodic check has not run yet');
        w.tracker.onResumed();
        expect(w.locked, isTrue);
      });
    },
  );

  test('(d) resumed within the period does nothing', () {
    fakeAsync((async) {
      final w = _Window(async, FakeLockChannelHub().create());
      async.elapse(const Duration(minutes: 2));
      w.tracker.onResumed();
      expect(w.locked, isFalse);
    });
  });

  test('(e) signed out: no lock and no timer armed', () {
    fakeAsync((async) {
      final w = _Window(async, FakeLockChannelHub().create(), signedIn: false);
      async.elapse(const Duration(minutes: 30));
      w.tracker.onResumed();
      expect(w.lockCalls, 0);
      expect(async.periodicTimerCount, 0);
    });
  });

  test('(g) a sign-out stops the timer, a sign-in starts it', () {
    fakeAsync((async) {
      final w = _Window(async, FakeLockChannelHub().create());
      expect(async.periodicTimerCount, 1);
      w.signedIn = false;
      w.tracker.onSignedInChanged(false);
      expect(async.periodicTimerCount, 0);
      w.signedIn = true;
      w.tracker.onSignedInChanged(true);
      expect(async.periodicTimerCount, 1);
    });
  });

  test('(g) an unlock restarts the period and tells the other windows', () {
    fakeAsync((async) {
      final channel = FakeLockChannelHub().create();
      final w = _Window(async, channel);
      async.elapse(const Duration(minutes: 6));
      expect(w.locked, isTrue);
      w.unlockLocally();
      expect(channel.sentOfType(LockMessageType.unlock), hasLength(1));
      async.elapse(const Duration(minutes: 4));
      expect(w.locked, isFalse, reason: 'the period restarted at the unlock');
      async.elapse(const Duration(minutes: 2));
      expect(w.locked, isTrue);
    });
  });

  group('(h) two windows over the channel', () {
    test('interaction only in B keeps A unlocked for 20 minutes', () {
      fakeAsync((async) {
        final hub = FakeLockChannelHub();
        final a = _Window(async, hub.create('a'));
        final b = _Window(async, hub.create('b'));
        for (var i = 0; i < 20; i++) {
          async.elapse(const Duration(minutes: 1));
          b.tracker.recordInteraction();
        }
        expect(a.locked, isFalse);
        expect(b.locked, isFalse);
      });
    });

    test('both idle → both lock; the lock is mirrored, not re-broadcast', () {
      fakeAsync((async) {
        final hub = FakeLockChannelHub();
        final a = _Window(async, hub.create('a'));
        final chB = hub.create('b');
        // B only follows: its own check never runs before the message arrives.
        final b = _Window(async, chB, checkInterval: const Duration(hours: 9));
        async.elapse(fiveMinutes + const Duration(seconds: 10));
        expect(a.locked, isTrue);
        expect(b.locked, isTrue);
        expect(b.lockCalls, 1);
        expect(chB.sentOfType(LockMessageType.lock), isEmpty);
      });
    });

    test('unlocking in A unlocks B, without an echo back', () {
      fakeAsync((async) {
        final hub = FakeLockChannelHub();
        final chA = hub.create('a');
        final a = _Window(async, chA);
        final chB = hub.create('b');
        final b = _Window(async, chB);
        async.elapse(fiveMinutes + const Duration(seconds: 10));
        expect(a.locked && b.locked, isTrue);
        a.unlockLocally();
        expect(b.locked, isFalse);
        expect(b.unlockCalls, 1);
        expect(chB.sentOfType(LockMessageType.unlock), isEmpty);
        expect(chA.sentOfType(LockMessageType.unlock), hasLength(1));
      });
    });
  });

  test('(i) activity messages are sent at most once every 5 seconds', () {
    fakeAsync((async) {
      final channel = FakeLockChannelHub().create();
      final w = _Window(async, channel);
      for (var i = 0; i < 100; i++) {
        w.tracker.recordInteraction();
      }
      expect(channel.sentOfType(LockMessageType.activity), hasLength(1));
      async.elapse(const Duration(seconds: 5));
      w.tracker.recordInteraction();
      expect(channel.sentOfType(LockMessageType.activity), hasLength(2));
    });
  });

  group('(j) a window that merely loads', () {
    test('starting locked sends nothing and does not lock a window in use', () {
      fakeAsync((async) {
        final hub = FakeLockChannelHub();
        final inUse = _Window(async, hub.create('a'));
        async.elapse(const Duration(minutes: 1));
        inUse.tracker.recordInteraction();
        final chNew = hub.create('b');
        final fresh = _Window(async, chNew, locked: true);
        expect(fresh.locked, isTrue);
        expect(chNew.sentOfType(LockMessageType.lock), isEmpty);
        expect(inUse.locked, isFalse);
        expect(inUse.lockCalls, 0);
      });
    });

    test('unlocking it (a password sign-in) unlocks a locked first window', () {
      fakeAsync((async) {
        final hub = FakeLockChannelHub();
        final first = _Window(async, hub.create('a'));
        async.elapse(fiveMinutes + const Duration(seconds: 10));
        expect(first.locked, isTrue);
        final fresh = _Window(async, hub.create('b'), locked: true);
        fresh.unlockLocally();
        expect(first.locked, isFalse);
      });
    });
  });

  group('(k) FR-005: locking leaves sync alone', () {
    test('the sync worker and the pull service are neither rebuilt nor '
        'disposed by a lock and an unlock', () {
      var syncCreated = 0, syncDisposed = 0;
      var pullCreated = 0, pullDisposed = 0;
      final container = ProviderContainer(
        overrides: [
          authStateChangesProvider.overrideWith(
            (ref) => const Stream<AuthState>.empty(),
          ),
          isSignedInProvider.overrideWithValue(true),
          lockChannelProvider.overrideWithValue(FakeLockChannelHub().create()),
          syncWorkerProvider.overrideWith((ref) {
            syncCreated++;
            ref.onDispose(() => syncDisposed++);
            return _FakeSyncWorker();
          }),
          pullServiceProvider.overrideWith((ref) {
            pullCreated++;
            ref.onDispose(() => pullDisposed++);
            return null as PullService?;
          }),
        ],
      );
      addTearDown(container.dispose);

      container.read(syncWorkerProvider);
      container.read(pullServiceProvider);
      container.read(activityTrackerProvider);

      container.read(appLockProvider.notifier).lock();
      expect(container.read(appLockProvider), isTrue);
      container.read(appLockProvider.notifier).unlock();
      expect(container.read(appLockProvider), isFalse);

      expect((syncCreated, syncDisposed), (1, 0));
      expect((pullCreated, pullDisposed), (1, 0));
    });
  });
}
