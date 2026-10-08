import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/sync/reconciliation_monitor.dart';
import 'package:finance/core/sync/sync_notice.dart';

final _start = DateTime(2026, 10, 8, 12);
const _settle = Duration(seconds: 10);

/// A monitor on the fake clock of [async] whose divergence is a plain list the
/// test edits, and whose `resync` is a counter (optionally healing).
class _Rig {
  _Rig(
    FakeAsync async, {
    this.healOnResync = false,
    this.resyncAvailable = true,
  }) {
    monitor = ReconciliationMonitor(
      findDivergent: () async => List.of(divergent),
      itemName: (id) async => 'Item $id',
      report: reported.add,
      resync: () async {
        if (!resyncAvailable) return false;
        resyncs++;
        if (healOnResync) divergent.clear();
        return true;
      },
      settleDelay: _settle,
      now: () => async.getClock(_start).now(),
    );
  }

  late final ReconciliationMonitor monitor;
  final divergent = <String>[];
  final reported = <SyncNotice>[];
  final bool healOnResync;
  final bool resyncAvailable;
  int resyncs = 0;
}

void main() {
  test('no divergence: nothing happens and nothing is scheduled', () {
    fakeAsync((async) {
      final rig = _Rig(async);
      rig.monitor.check();
      async.flushMicrotasks();
      async.elapse(const Duration(minutes: 5));

      expect(rig.resyncs, 0);
      expect(rig.reported, isEmpty);
    });
  });

  test(
    'seen once: no resync and no notice yet, one more check is scheduled',
    () {
      fakeAsync((async) {
        final rig = _Rig(async)..divergent.add('a');
        rig.monitor.check();
        async.flushMicrotasks();

        expect(rig.resyncs, 0);
        expect(rig.reported, isEmpty);
        expect(async.pendingTimers, hasLength(1));
      });
    },
  );

  test('still divergent after the settle delay: one resync, then one notice '
      'with the item name and no amount, within 30 seconds (SC-008)', () {
    fakeAsync((async) {
      final rig = _Rig(async)..divergent.add('a');
      rig.monitor.check();
      async.flushMicrotasks();
      async.elapse(_settle);
      async.flushMicrotasks();

      expect(rig.resyncs, 1);
      expect(rig.reported, hasLength(1));
      final notice = rig.reported.single;
      expect(notice.reason, SyncNoticeReason.balanceMismatch);
      expect(notice.itemName, 'Item a');
      expect(notice.amount, isNull);
      expect(notice.id, 'mismatch:a');
      expect(async.elapsed, lessThanOrEqualTo(const Duration(seconds: 30)));
    });
  });

  test('a difference that disappears before the settle delay: no resync, no '
      'notice', () {
    fakeAsync((async) {
      final rig = _Rig(async)..divergent.add('a');
      rig.monitor.check();
      async.flushMicrotasks();
      rig.divergent.clear();
      async.elapse(_settle * 2);
      async.flushMicrotasks();

      expect(rig.resyncs, 0);
      expect(rig.reported, isEmpty);
    });
  });

  test('a difference that disappears after the resync: no notice', () {
    fakeAsync((async) {
      final rig = _Rig(async, healOnResync: true)..divergent.add('a');
      rig.monitor.check();
      async.flushMicrotasks();
      async.elapse(_settle);
      async.flushMicrotasks();

      expect(rig.resyncs, 1);
      expect(rig.reported, isEmpty);
    });
  });

  test('a resync that cannot run (signed out) reports nothing and schedules '
      'nothing: the next settled point looks again', () {
    fakeAsync((async) {
      final rig = _Rig(async, resyncAvailable: false)..divergent.add('a');
      rig.monitor.check();
      async.flushMicrotasks();
      async.elapse(_settle);
      async.flushMicrotasks();

      expect(rig.reported, isEmpty);
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('a notice is reported once until the item converges, and again if it '
      'diverges again later', () {
    fakeAsync((async) {
      final rig = _Rig(async)..divergent.add('a');
      rig.monitor.check();
      async.flushMicrotasks();
      async.elapse(_settle);
      async.flushMicrotasks();
      rig.monitor.check();
      async.flushMicrotasks();
      async.elapse(_settle * 3);
      async.flushMicrotasks();
      expect(rig.reported, hasLength(1));
      expect(rig.resyncs, 1);

      rig.divergent.clear();
      rig.monitor.check();
      async.flushMicrotasks();
      rig.divergent.add('a');
      rig.monitor.check();
      async.flushMicrotasks();
      async.elapse(_settle);
      async.flushMicrotasks();

      expect(rig.reported, hasLength(2));
      expect(rig.resyncs, 2);
    });
  });

  test('two items are tracked independently', () {
    fakeAsync((async) {
      final rig = _Rig(async)..divergent.add('a');
      rig.monitor.check();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 6));
      rig.divergent.add('b'); // first seen 6 s after a
      rig.monitor.check();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 4)); // a settles at 10 s, b not yet
      async.flushMicrotasks();

      expect(rig.reported.map((n) => n.id), ['mismatch:a']);

      async.elapse(const Duration(seconds: 6));
      async.flushMicrotasks();
      expect(rig.reported.map((n) => n.id), ['mismatch:a', 'mismatch:b']);
    });
  });

  test('two overlapping check() calls produce one timer, one resync and one '
      'notice', () {
    fakeAsync((async) {
      final rig = _Rig(async)..divergent.add('a');
      rig.monitor.check();
      rig.monitor.check();
      async.flushMicrotasks();
      expect(async.pendingTimers, hasLength(1));

      async.elapse(_settle);
      async.flushMicrotasks();
      rig.monitor.check();
      rig.monitor.check();
      async.flushMicrotasks();

      expect(rig.resyncs, 1);
      expect(rig.reported, hasLength(1));
    });
  });
}
