import 'package:drift/drift.dart' as drift;
import 'package:drift/drift.dart' show QueryExecutor, QueryInterceptor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/database/app_database.dart';
import 'package:finance/core/sync/pull_service.dart';
import 'package:finance/core/sync/sync_outbox_table.dart';

const _userId = 'test-user';

Map<String, dynamic> _itemJson(
  String id, {
  String name = 'Food',
  required DateTime updatedAt,
}) {
  return {
    'id': id,
    'user_id': _userId,
    'name': name,
    'icon_key': 'utensils',
    'sort_order': 0,
    'balance': 0,
    'balance_base': 0,
    'is_savings_receiver': false,
    'created_at': updatedAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

/// A no-op subscribe closure for tests that only exercise
/// `runInitialPull()` directly and never call `start()` — `onReady` is
/// never invoked, matching production's real timing (subscribe doesn't
/// synchronously guarantee anything is ready).
Future<void> Function() _noopSubscribe(
  List<String> tables,
  void Function(String table, Map<String, dynamic> row) onEvent,
  void Function() onReady,
) {
  return () async {};
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('keyset pagination', () {
    test('a fetch with no cursor starts from the beginning (FR-001)', () async {
      Map<String, dynamic>? capturedCursor;
      final service = PullService(
        db,
        userId: _userId,
        batchSize: 100,
        subscribe: _noopSubscribe,
        fetchBatch: (table, userId, cursor) async {
          capturedCursor = cursor;
          return const [];
        },
      );

      await service.runInitialPull();

      expect(capturedCursor, isNull);
    });

    test('a fetch with an existing cursor uses WHERE (updated_at, id) > '
        '(cursor_updated_at, cursor_id) (research.md Decision 4)', () async {
      // Seed a PullCursor as if a prior batch already committed.
      final priorUpdatedAt = DateTime.utc(2026, 1, 1);
      await db
          .into(db.pullCursor)
          .insert(
            PullCursorCompanion.insert(
              userId: _userId,
              syncTableName: 'expense_control_items',
              lastUpdatedAt: drift.Value(priorUpdatedAt),
              lastId: const drift.Value('prior-id'),
            ),
          );

      Map<String, dynamic>? capturedCursor;
      final service = PullService(
        db,
        userId: _userId,
        batchSize: 100,
        subscribe: _noopSubscribe,
        fetchBatch: (table, userId, cursor) async {
          if (table == 'expense_control_items') {
            capturedCursor = cursor;
          }
          return const [];
        },
      );

      await service.runInitialPull();

      expect(capturedCursor, {
        'updated_at': priorUpdatedAt.toIso8601String(),
        'id': 'prior-id',
      });
    });

    test(
      'a batch returning fewer rows than the batch size marks '
      'initialPullCompleted = true (data-model.md PullCursor lifecycle)',
      () async {
        final service = PullService(
          db,
          userId: _userId,
          batchSize: 10,
          subscribe: _noopSubscribe,
          fetchBatch: (table, userId, cursor) async {
            if (table != 'expense_control_items') return const [];
            // Fewer than batchSize (10) — the standard "no more pages"
            // keyset-pagination signal.
            return [_itemJson('food', updatedAt: DateTime.utc(2026, 1, 1))];
          },
        );

        await service.runInitialPull();

        final cursor =
            await (db.select(db.pullCursor)..where(
                  (t) =>
                      t.userId.equals(_userId) &
                      t.syncTableName.equals('expense_control_items'),
                ))
                .getSingle();
        expect(cursor.initialPullCompleted, isTrue);
      },
    );
  });

  group('subscribe-before-fetch ordering (research.md Decision 2)', () {
    test("subscribing does not itself run the catch-up fetch — the fetch "
        "runs only once the subscription reports it's actually ready "
        '(onReady), matching production timing where subscribe() returns '
        "synchronously without waiting for connection", () async {
      final callOrder = <String>[];
      void Function()? triggerReady;
      final service = PullService(
        db,
        userId: _userId,
        batchSize: 100,
        subscribe: (tables, onEvent, onReady) {
          callOrder.add('subscribe');
          triggerReady = onReady;
          return () async {};
        },
        fetchBatch: (table, userId, cursor) async {
          callOrder.add('fetch:$table');
          return const [];
        },
      );

      await service.start();
      expect(callOrder, ['subscribe']); // fetch has NOT run yet

      triggerReady!();
      await service.drainReadyPulls();

      expect(callOrder.first, 'subscribe');
      expect(callOrder.skip(1), contains('fetch:expense_control_items'));
      expect(callOrder.skip(1), contains('fetch:financial_transactions'));
    });

    test('a change event arriving during the initial fetch is applied via '
        'the same idempotent path and does not corrupt or duplicate the '
        "fetch's own application of that row", () async {
      void Function(String table, Map<String, dynamic> row)? deliverEvent;
      void Function()? triggerReady;
      final service = PullService(
        db,
        userId: _userId,
        batchSize: 100,
        subscribe: (tables, onEvent, onReady) {
          deliverEvent = onEvent;
          triggerReady = onReady;
          return () async {};
        },
        fetchBatch: (table, userId, cursor) async {
          if (table != 'expense_control_items') return const [];
          // While this batch is "in flight," a live change event for the
          // same row arrives via the channel, delivering a NEWER version.
          deliverEvent?.call(
            'expense_control_items',
            _itemJson(
              'food',
              name: 'Live Update',
              updatedAt: DateTime.utc(2026, 1, 2),
            ),
          );
          return [_itemJson('food', updatedAt: DateTime.utc(2026, 1, 1))];
        },
      );

      await service.start();
      triggerReady!();
      await service.drainReadyPulls();
      // The live event's write is chained, not fired-and-forgotten
      // (research.md/T019's design) — wait for it deterministically
      // rather than relying on incidental event-loop timing.
      await service.drainLiveWrites();

      final rows = await db.select(db.expenseControlItems).get();
      expect(rows, hasLength(1));
      // The live event's newer value wins — no duplicate, no corruption.
      expect(rows.single.name, 'Live Update');
    });
  });

  group('per-batch transactionality (FR-010)', () {
    test(
      'each batch is committed as its own local transaction; the cursor '
      'advances only after a batch\'s transaction commits successfully',
      () async {
        var batchCount = 0;
        final service = PullService(
          db,
          userId: _userId,
          batchSize: 2,
          subscribe: _noopSubscribe,
          fetchBatch: (table, userId, cursor) async {
            if (table != 'expense_control_items') return const [];
            batchCount++;
            if (batchCount == 1) {
              return [
                _itemJson('a', updatedAt: DateTime.utc(2026, 1, 1)),
                _itemJson('b', updatedAt: DateTime.utc(2026, 1, 2)),
              ];
            }
            // Second batch: fewer than batchSize, ends pagination.
            return [_itemJson('c', updatedAt: DateTime.utc(2026, 1, 3))];
          },
        );

        await service.runInitialPull();

        final rows = await db.select(db.expenseControlItems).get();
        expect(rows, hasLength(3));

        final cursor =
            await (db.select(db.pullCursor)..where(
                  (t) =>
                      t.userId.equals(_userId) &
                      t.syncTableName.equals('expense_control_items'),
                ))
                .getSingle();
        // Cursor reflects the LAST row of the LAST batch, confirming each
        // batch's commit advanced it in order.
        expect(cursor.lastId, 'c');
        expect(cursor.initialPullCompleted, isTrue);
      },
    );

    test('a table whose row count is an EXACT multiple of batchSize still '
        'completes, and the final empty-batch fetch does not corrupt the '
        'already-recorded cursor position (regression: found during '
        '/speckit-implement — the empty-batch branch previously only '
        'marked completed when cursor was null, and separately once did so '
        'it overwrote a real cursor position with null)', () async {
      var fetchCount = 0;
      final service = PullService(
        db,
        userId: _userId,
        batchSize: 2,
        subscribe: _noopSubscribe,
        fetchBatch: (table, userId, cursor) async {
          if (table != 'expense_control_items') return const [];
          fetchCount++;
          if (fetchCount == 1) {
            // Exactly batchSize (2) rows — isLastPage miscalculates
            // false for this batch alone.
            return [
              _itemJson('a', updatedAt: DateTime.utc(2026, 1, 1)),
              _itemJson('b', updatedAt: DateTime.utc(2026, 1, 2)),
            ];
          }
          // Second fetch: genuinely no more rows.
          return const [];
        },
      );

      await service.runInitialPull();

      final rows = await db.select(db.expenseControlItems).get();
      expect(rows, hasLength(2));

      final cursor =
          await (db.select(db.pullCursor)..where(
                (t) =>
                    t.userId.equals(_userId) &
                    t.syncTableName.equals('expense_control_items'),
              ))
              .getSingle();
      expect(cursor.initialPullCompleted, isTrue);
      // The real cursor position from the first (full) batch survives —
      // not wiped to null by the second, empty-batch fetch.
      expect(cursor.lastId, 'b');
      expect(cursor.lastUpdatedAt, DateTime.utc(2026, 1, 2));
    });
  });

  group('reconnect handling (FR-002a, research.md Decision 5)', () {
    test('a second onReady call (simulating a disconnect-then-reconnect '
        'status transition) re-runs the catch-up fetch starting from the '
        'existing cursor position, not a null/reset one', () async {
      void Function()? triggerReady;
      final fetchedCursors = <Map<String, dynamic>?>[];
      var fetchCount = 0;
      final service = PullService(
        db,
        userId: _userId,
        batchSize: 100,
        subscribe: (tables, onEvent, onReady) {
          triggerReady = onReady;
          return () async {};
        },
        fetchBatch: (table, userId, cursor) async {
          if (table != 'expense_control_items') return const [];
          fetchCount++;
          fetchedCursors.add(cursor);
          if (fetchCount == 1) {
            // Initial pull: one full batch, establishing a cursor.
            return [_itemJson('a', updatedAt: DateTime.utc(2026, 1, 1))];
          }
          // The reconnect-triggered re-fetch: nothing new server-side,
          // but the important assertion is WHAT cursor this call used.
          return const [];
        },
      );

      await service.start();
      triggerReady!(); // first connect
      await service.drainReadyPulls();
      expect(fetchCount, 1);
      expect(fetchedCursors.single, isNull); // initial pull: no cursor yet

      // Simulate the subscription reporting a reconnect: onReady fires
      // again (Subscribe's contract — see its own doc for why the first
      // connect and a later reconnect are the same signal).
      triggerReady!();
      await service.drainReadyPulls();

      expect(fetchCount, 2);
      // The reconnect's re-fetch used the cursor the initial pull left
      // behind — resuming, not restarting from null.
      expect(fetchedCursors.last, {
        'updated_at': DateTime.utc(2026, 1, 1).toIso8601String(),
        'id': 'a',
      });
    });
  });

  group('offline-at-sign-in (FR-006, `/speckit-analyze` finding E1)', () {
    test('start() called while offline does not throw or block indefinitely '
        '— once connectivity becomes available and onReady eventually '
        'fires, the initial subscribe+fetch completes without requiring '
        'start() to be called again', () async {
      void Function()? triggerReady;
      var fetchCount = 0;
      final service = PullService(
        db,
        userId: _userId,
        batchSize: 100,
        subscribe: (tables, onEvent, onReady) {
          // Simulates a device offline at the moment start() is called:
          // subscribe() itself still returns synchronously (production's
          // real .subscribe() call never blocks the caller either), but
          // onReady is not invoked here — only later, when the test
          // explicitly simulates connectivity returning.
          triggerReady = onReady;
          return () async {};
        },
        fetchBatch: (table, userId, cursor) async {
          if (table != 'expense_control_items') return const [];
          fetchCount++;
          return [_itemJson('food', updatedAt: DateTime.utc(2026, 1, 1))];
        },
      );

      // start() returns promptly even though nothing has connected yet —
      // it does not throw, and does not hang waiting for onReady.
      await service.start();
      expect(fetchCount, 0);

      // Connectivity "becomes available" — the subscription's own retry/
      // backoff (realtime_client's built-in reconnection) eventually
      // reports ready, exactly like any later reconnect would.
      triggerReady!();
      await service.drainReadyPulls();

      expect(fetchCount, 1);
      final rows = await db.select(db.expenseControlItems).get();
      expect(rows, hasLength(1));
    });
  });

  group('derived balances and reconciliation hooks', () {
    Map<String, dynamic> txJson(
      String id,
      String itemId,
      int amount,
      DateTime at,
    ) {
      return {
        'id': id,
        'user_id': _userId,
        'expense_control_item_id': itemId,
        'direction': 'expense',
        'amount': amount,
        'occurred_at': at.toIso8601String(),
        'created_at': at.toIso8601String(),
        'updated_at': at.toIso8601String(),
      };
    }

    test('a batch of 600 transactions over 3 items recomputes each touched '
        'item once per batch, not once per row', () async {
      // A second database (the counting one) next to setUp's is deliberate.
      drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final counter = _RecomputeCounter();
      final countingDb = AppDatabase.forTesting(
        NativeDatabase.memory().interceptWith(counter),
      );
      addTearDown(countingDb.close);
      final base = DateTime.utc(2026, 1, 1);

      final service = PullService(
        countingDb,
        userId: _userId,
        batchSize: 1000,
        subscribe: _noopSubscribe,
        fetchBatch: (table, userId, cursor) async {
          if (cursor != null) return const [];
          if (table == 'expense_control_items') {
            return [
              for (final id in ['a', 'b', 'c']) _itemJson(id, updatedAt: base),
            ];
          }
          return [
            for (var i = 0; i < 600; i++)
              txJson(
                'tx$i',
                ['a', 'b', 'c'][i % 3],
                10,
                base.add(Duration(seconds: i + 1)),
              ),
          ];
        },
      );

      await service.runInitialPull();

      final items = await countingDb
          .select(countingDb.expenseControlItems)
          .get();
      expect(items.map((i) => i.balance), everyElement(-2000));
      // Three items in the item batch plus three in the transaction batch.
      expect(counter.recomputeStatements, 6);
      // The cursor still moved only because the batches committed.
      final cursor =
          await (countingDb.select(
                countingDb.pullCursor,
              )..where((t) => t.syncTableName.equals('financial_transactions')))
              .getSingle();
      expect(cursor.initialPullCompleted, isTrue);
    });

    test('a live event applies and recomputes', () async {
      void Function(String table, Map<String, dynamic> row)? deliverEvent;
      final service = PullService(
        db,
        userId: _userId,
        subscribe: (tables, onEvent, onReady) {
          deliverEvent = onEvent;
          return () async {};
        },
        fetchBatch: (table, userId, cursor) async => const [],
      );
      await service.start();
      final base = DateTime.utc(2026, 1, 1);

      deliverEvent!('expense_control_items', _itemJson('a', updatedAt: base));
      deliverEvent!(
        'financial_transactions',
        txJson('t', 'a', 70, base.add(const Duration(seconds: 1))),
      );
      await service.drainLiveWrites();

      final item = await (db.select(
        db.expenseControlItems,
      )..where((t) => t.id.equals('a'))).getSingle();
      expect(item.balance, -70);
    });

    test('onCaughtUp is called once after a catch-up pull completes', () async {
      var calls = 0;
      final service = PullService(
        db,
        userId: _userId,
        subscribe: _noopSubscribe,
        fetchBatch: (table, userId, cursor) async => const [],
        onCaughtUp: () => calls++,
      );

      await service.runInitialPull();

      expect(calls, 1);
    });

    test(
      'onConnected requests an outbox drain whenever realtime is ready',
      () async {
        void Function() triggerReady = () {};
        var calls = 0;
        final service = PullService(
          db,
          userId: _userId,
          subscribe: (tables, onEvent, onReady) {
            triggerReady = onReady;
            return () async {};
          },
          fetchBatch: (table, userId, cursor) async => const [],
          onConnected: () => calls++,
        );
        await service.start();

        triggerReady();
        await service.drainReadyPulls();
        triggerReady();
        await service.drainReadyPulls();

        expect(calls, 2);
      },
    );

    test('resync replaces a stale local row (even one stamped in the future) '
        'but not a row that has a change waiting in the outbox', () async {
      final server = DateTime.utc(2026, 1, 1);
      final future = DateTime.utc(2099, 1, 1);
      for (final id in ['stale', 'pending']) {
        await db
            .into(db.expenseControlItems)
            .insert(
              ExpenseControlItemsCompanion.insert(
                id: id,
                userId: _userId,
                name: 'Local $id',
                iconKey: 'utensils',
                updatedAt: drift.Value(future),
              ),
            );
      }
      await db
          .into(db.syncOutbox)
          .insert(
            SyncOutboxCompanion.insert(
              id: 'o1',
              entityTable: 'expense_control_items',
              rowId: 'pending',
              operation: SyncOperation.update,
              payload: '{}',
            ),
          );
      final service = PullService(
        db,
        userId: _userId,
        subscribe: _noopSubscribe,
        fetchBatch: (table, userId, cursor) async {
          if (table != 'expense_control_items' || cursor != null) {
            return const [];
          }
          return [
            _itemJson('stale', name: 'Server stale', updatedAt: server),
            _itemJson('pending', name: 'Server pending', updatedAt: server),
          ];
        },
      );

      await service.resync();

      final byId = {
        for (final i in await db.select(db.expenseControlItems).get()) i.id: i,
      };
      expect(byId['stale']!.name, 'Server stale');
      expect(byId['stale']!.updatedAt, server);
      expect(byId['pending']!.name, 'Local pending');
    });

    test('resync re-fetches both tables from the beginning in batches and '
        'leaves the stored cursors and the completed flag untouched', () async {
      final base = DateTime.utc(2026, 1, 1);
      final cursorsSeen = <String, List<Map<String, dynamic>?>>{};
      final service = PullService(
        db,
        userId: _userId,
        batchSize: 2,
        subscribe: _noopSubscribe,
        fetchBatch: (table, userId, cursor) async {
          (cursorsSeen[table] ??= []).add(cursor);
          if (table == 'financial_transactions') return const [];
          if (cursor == null) {
            return [
              _itemJson('a', updatedAt: base),
              _itemJson('b', updatedAt: base.add(const Duration(seconds: 1))),
            ];
          }
          return [
            _itemJson('c', updatedAt: base.add(const Duration(seconds: 2))),
          ];
        },
      );
      await service.runInitialPull();
      final cursorBefore = await db.select(db.pullCursor).get();
      cursorsSeen.clear();

      await service.resync();

      // It started over: the first fetch of every table had no cursor.
      expect(cursorsSeen['expense_control_items']!.first, isNull);
      expect(cursorsSeen['financial_transactions']!.first, isNull);
      expect(await db.select(db.expenseControlItems).get(), hasLength(3));
      final cursorAfter = await db.select(db.pullCursor).get();
      expect(
        cursorAfter.map(
          (c) => '${c.syncTableName}:${c.lastId}:${c.initialPullCompleted}',
        ),
        cursorBefore.map(
          (c) => '${c.syncTableName}:${c.lastId}:${c.initialPullCompleted}',
        ),
      );
    });
  });
}

/// Counts the `UPDATE expense_control_items SET balance` statements the
/// ledger issues, whichever executor entry point carries them.
class _RecomputeCounter extends QueryInterceptor {
  int recomputeStatements = 0;

  void _count(String statement) {
    if (statement.contains('UPDATE expense_control_items SET balance')) {
      recomputeStatements++;
    }
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    _count(statement);
    return executor.runUpdate(statement, args);
  }

  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    _count(statement);
    return executor.runCustom(statement, args);
  }
}
