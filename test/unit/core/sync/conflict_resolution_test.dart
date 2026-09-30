import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finance/core/database/app_database.dart';
import 'package:finance/core/sync/remote_row_writer.dart';
import 'package:finance/core/sync/sync_outbox_table.dart';
import 'package:finance/core/sync/sync_worker.dart';
import 'package:finance/features/expense_control/data/expense_control_repository_impl.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';

const _userId = 'test-user';

ExpenseControlItemRow _itemRow(
  String id, {
  String userId = _userId,
  String name = 'Food',
  int balance = 0,
  required DateTime updatedAt,
  DateTime? deletedAt,
}) {
  return ExpenseControlItemRow(
    id: id,
    userId: userId,
    parentId: null,
    name: name,
    iconKey: 'utensils',
    description: null,
    sortOrder: 0,
    allocationMethod: null,
    allocationValue: null,
    balance: balance,
    isSavingsReceiver: false,
    createdAt: updatedAt,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('research.md Decision 8 — conflict resolution algorithm', () {
    test(
      '(a) a pending outbox entry survives an incoming pull for the same '
      'row unmodified (SC-004 — the outbox is never touched by '
      'applyRemoteExpenseControlItem)',
      () async {
        // Device A: a local edit is pending (unsynced outbox entry).
        await db
            .into(db.expenseControlItems)
            .insert(
              ExpenseControlItemsCompanion.insert(
                id: 'food',
                userId: _userId,
                name: 'Locally Renamed',
                iconKey: 'utensils',
                updatedAt: Value(DateTime.utc(2026, 1, 1)),
              ),
            );
        await db
            .into(db.syncOutbox)
            .insert(
              SyncOutboxCompanion.insert(
                id: 'outbox-1',
                entityTable: 'expense_control_items',
                rowId: 'food',
                operation: SyncOperation.update,
                payload: '{}',
              ),
            );

        // A pull delivers Device B's already-synced version of the same row.
        final pulledRow = _itemRow(
          'food',
          name: 'Device B Renamed',
          updatedAt: DateTime.utc(2026, 1, 2),
        );
        await applyRemoteExpenseControlItem(db, _userId, pulledRow);

        // The pending outbox entry is untouched and still queued.
        final outboxRows = await db.select(db.syncOutbox).get();
        expect(outboxRows, hasLength(1));
        expect(outboxRows.single.syncedAt, isNull);
      },
    );

    test(
      '(b) after a pending entry drains and its read-back lands, a '
      'subsequent Realtime rebroadcast of the same push is a no-op (step 5)',
      () async {
        final readBackUpdatedAt = DateTime.utc(2026, 1, 3);
        final readBackRow = _itemRow(
          'food',
          name: 'Pushed Name',
          updatedAt: readBackUpdatedAt,
        );
        // Simulates SyncWorker's own read-back write (T013/T014).
        await applyRemoteExpenseControlItem(db, _userId, readBackRow);

        // The Realtime channel rebroadcasts this device's own just-pushed
        // write back to it — same id, same (or equal) updated_at.
        final rebroadcastRow = _itemRow(
          'food',
          name: 'Pushed Name',
          updatedAt: readBackUpdatedAt,
        );
        await applyRemoteExpenseControlItem(db, _userId, rebroadcastRow);

        final stored =
            await (db.select(
              db.expenseControlItems,
            )..where((t) => t.id.equals('food'))).getSingle();
        expect(stored.name, 'Pushed Name');
        expect(stored.updatedAt, readBackUpdatedAt);
      },
    );

    test(
      '(c) a balance field always takes the pulled/live value as-is '
      'regardless of any pending non-balance edit (constitution\'s '
      'server-authoritative-balance carve-out, spec.md User Story 2 '
      'Acceptance Scenario 2)',
      () async {
        // A pending, unsynced local edit to a non-balance field exists.
        await db
            .into(db.expenseControlItems)
            .insert(
              ExpenseControlItemsCompanion.insert(
                id: 'food',
                userId: _userId,
                name: 'Locally Renamed',
                iconKey: 'utensils',
                balance: const Value(100),
                updatedAt: Value(DateTime.utc(2026, 1, 1)),
              ),
            );
        await db
            .into(db.syncOutbox)
            .insert(
              SyncOutboxCompanion.insert(
                id: 'outbox-1',
                entityTable: 'expense_control_items',
                rowId: 'food',
                operation: SyncOperation.update,
                payload: '{}',
              ),
            );

        // The server's authoritative balance diverges (e.g. an allocation
        // on another device).
        final pulledRow = _itemRow(
          'food',
          name: 'Locally Renamed',
          balance: 500,
          updatedAt: DateTime.utc(2026, 1, 2),
        );
        await applyRemoteExpenseControlItem(db, _userId, pulledRow);

        final stored =
            await (db.select(
              db.expenseControlItems,
            )..where((t) => t.id.equals('food'))).getSingle();
        // The server-authoritative balance wins as-is — never held back or
        // merged with local state.
        expect(stored.balance, 500);
      },
    );
  });

  group('SC-006 — clock-skew resolution (research.md Decision 8/FR-005a)', () {
    test(
      'a push from a device with a skewed local clock is resolved by '
      'server real time (the FR-005a trigger\'s now()), never by either '
      'device\'s own DateTime.now()',
      () async {
        // Two "devices" push the same row around the same real moment, but
        // Device A's system clock is set 10 minutes AHEAD of real time and
        // Device B's is set 5 minutes BEHIND — exactly the scenario SC-006
        // names ("deliberately setting one test device's clock ahead of or
        // behind another's"). Neither device's skewed DateTime.now() is
        // read anywhere in this test — only the payload's content (the
        // name each device wrote) and the fake `push`'s simulated,
        // real-time-ordered server response matter, which is the point:
        // the algorithm has no client-clock dependency left to skew.
        final realT0 = DateTime.utc(2026, 6, 1, 12);

        final deviceASkewedClock = Clock.fixed(
          realT0.add(const Duration(minutes: 10)),
        );
        final deviceBSkewedClock = Clock.fixed(
          realT0.subtract(const Duration(minutes: 5)),
        );

        // Device A pushes first in real time (realT0), but its own skewed
        // clock would claim it's 10 minutes further into the future than
        // it really is.
        final deviceAPayload = withClock(deviceASkewedClock, () {
          return {
            'id': 'food',
            'user_id': _userId,
            'name': 'Device A Name',
            'icon_key': 'utensils',
            'sort_order': 0,
            'balance': 0,
            'is_savings_receiver': false,
            'created_at': realT0.toIso8601String(),
            // What the client WOULD send if nothing overrode it — the
            // trigger ignores this regardless (research.md Decision 1).
            'updated_at': clock.now().toIso8601String(),
          };
        });

        final worker = SyncWorker(
          db,
          SupabaseClient('https://example.invalid', 'anon-key-unused'),
          push: (table, sentPayload) async {
            // Simulates the real FR-005a trigger: the server's actual
            // now() at the moment it processes this push, NOT the skewed
            // client-supplied value above.
            return {...sentPayload, 'updated_at': realT0.toIso8601String()};
          },
        );

        await db
            .into(db.syncOutbox)
            .insert(
              SyncOutboxCompanion.insert(
                id: 'outbox-a',
                entityTable: 'expense_control_items',
                rowId: 'food',
                operation: SyncOperation.update,
                payload: jsonEncode(deviceAPayload),
              ),
            );
        await worker.drainOutbox();

        var stored =
            await (db.select(
              db.expenseControlItems,
            )..where((t) => t.id.equals('food'))).getSingle();
        expect(stored.name, 'Device A Name');
        expect(stored.updatedAt, realT0);

        // Device B pushes 1 real second later (genuinely the later
        // real-world write), but its own skewed clock would claim it's 5
        // minutes BEHIND real time — if the algorithm used client clocks,
        // this write would incorrectly look "older" than Device A's and
        // could be dropped. It must still win, because it really did
        // happen later.
        final realT1 = realT0.add(const Duration(seconds: 1));
        final deviceBPayload = withClock(deviceBSkewedClock, () {
          return {
            'id': 'food',
            'user_id': _userId,
            'name': 'Device B Name',
            'icon_key': 'utensils',
            'sort_order': 0,
            'balance': 0,
            'is_savings_receiver': false,
            'created_at': realT0.toIso8601String(),
            'updated_at': clock.now().toIso8601String(),
          };
        });

        final workerB = SyncWorker(
          db,
          SupabaseClient('https://example.invalid', 'anon-key-unused'),
          push: (table, sentPayload) async {
            return {...sentPayload, 'updated_at': realT1.toIso8601String()};
          },
        );
        await db
            .into(db.syncOutbox)
            .insert(
              SyncOutboxCompanion.insert(
                id: 'outbox-b',
                entityTable: 'expense_control_items',
                rowId: 'food',
                operation: SyncOperation.update,
                payload: jsonEncode(deviceBPayload),
              ),
            );
        await workerB.drainOutbox();

        stored =
            await (db.select(
              db.expenseControlItems,
            )..where((t) => t.id.equals('food'))).getSingle();
        // Device B's write wins — it really happened later in server real
        // time (realT1 > realT0), regardless of either device's own
        // skewed local clock reading.
        expect(stored.name, 'Device B Name');
        expect(stored.updatedAt, realT1);
      },
    );
  });

  group('User Story 2 (spec.md Acceptance Scenarios)', () {
    test(
      '(T028) a real .update() edit\'s outbox entry survives an incoming '
      'pull, then wins once it drains with a newer server-issued '
      'updated_at (Acceptance Scenario 1, `/speckit-analyze` finding A1 — '
      'exercises the actual update()/outbox sequence via '
      'ExpenseControlRepositoryImpl, not a hand-constructed outbox row)',
      () async {
        final repository = ExpenseControlRepositoryImpl(db, userId: _userId);
        await db
            .into(db.expenseControlItems)
            .insert(
              ExpenseControlItemsCompanion.insert(
                id: 'food',
                userId: _userId,
                name: 'Original',
                iconKey: 'utensils',
                updatedAt: Value(DateTime.utc(2026, 1, 1)),
              ),
            );

        // Device A (this device): a real local edit via the actual public
        // API — produces a genuine sync_outbox row via _appendOutbox.
        await repository.update(
          const ExpenseControlItem(
            id: 'food',
            userId: _userId,
            parentId: null,
            name: 'Device A Renamed',
            iconKey: 'utensils',
            description: null,
            sortOrder: 0,
            allocationMethod: null,
            allocationValue: null,
            balance: 0,
            isSavingsReceiver: false,
          ),
        );
        final outboxAfterLocalEdit = await db.select(db.syncOutbox).get();
        expect(
          outboxAfterLocalEdit,
          hasLength(1),
          reason: 'the real .update() call must have queued a push',
        );

        // Device B: already-synced rename reaches this device via pull —
        // Device A's pending outbox entry must survive untouched.
        await applyRemoteExpenseControlItem(
          db,
          _userId,
          _itemRow(
            'food',
            name: 'Device B Renamed',
            updatedAt: DateTime.utc(2026, 1, 2),
          ),
        );
        final outboxAfterPull = await db.select(db.syncOutbox).get();
        expect(outboxAfterPull, hasLength(1));
        expect(outboxAfterPull.single.syncedAt, isNull);
        expect(outboxAfterPull.single.id, outboxAfterLocalEdit.single.id);

        // Device A's pending push finally lands, with a fresh,
        // even-newer server-issued updated_at (simulating SyncWorker's
        // own read-back, T013).
        await applyRemoteExpenseControlItem(
          db,
          _userId,
          _itemRow(
            'food',
            name: 'Device A Renamed',
            updatedAt: DateTime.utc(2026, 1, 3),
          ),
        );

        final stored =
            await (db.select(
              db.expenseControlItems,
            )..where((t) => t.id.equals('food'))).getSingle();
        // The later real-world write wins — Device A's push, which
        // reached the server after Device B's.
        expect(stored.name, 'Device A Renamed');
      },
    );

    test(
      '(T029) a pending non-balance local edit does not hold back or '
      'merge with an incoming pull\'s balance value (Acceptance Scenario '
      '2 — server-authoritative balance carve-out)',
      () async {
        final repository = ExpenseControlRepositoryImpl(db, userId: _userId);
        await db
            .into(db.expenseControlItems)
            .insert(
              ExpenseControlItemsCompanion.insert(
                id: 'food',
                userId: _userId,
                name: 'Original',
                iconKey: 'utensils',
                balance: const Value(100),
                updatedAt: Value(DateTime.utc(2026, 1, 1)),
              ),
            );

        // A pending, unsynced local edit to a non-balance field (name).
        await repository.update(
          const ExpenseControlItem(
            id: 'food',
            userId: _userId,
            parentId: null,
            name: 'Locally Renamed',
            iconKey: 'utensils',
            description: null,
            sortOrder: 0,
            allocationMethod: null,
            allocationValue: null,
            balance: 100,
            isSavingsReceiver: false,
          ),
        );

        // A pull carries a different, server-authoritative balance (e.g.
        // an allocation that happened on another device). updatedAt MUST
        // be strictly after repository.update()'s own DateTime.now() call
        // above for the pull to win per the <= idempotency check — a
        // fixed past date here would flakily fail once real time moves
        // past it (this WAS a real bug found running this test).
        await applyRemoteExpenseControlItem(
          db,
          _userId,
          _itemRow(
            'food',
            name: 'Locally Renamed',
            balance: 750,
            updatedAt: DateTime.now().add(const Duration(days: 1)),
          ),
        );

        final stored =
            await (db.select(
              db.expenseControlItems,
            )..where((t) => t.id.equals('food'))).getSingle();
        // The pulled balance wins as-is — never held back or merged with
        // the pending local edit's own balance value.
        expect(stored.balance, 750);
        // The pending outbox entry for the local name edit is untouched.
        final outboxRows = await db.select(db.syncOutbox).get();
        expect(outboxRows, hasLength(1));
        expect(outboxRows.single.syncedAt, isNull);
      },
    );
  });
}
