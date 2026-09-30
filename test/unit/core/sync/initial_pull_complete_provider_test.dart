import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/database/app_database.dart';
import 'package:finance/core/database/app_database_provider.dart';
import 'package:finance/core/sync/initial_pull_complete_provider.dart';

const _userId = 'test-user';

/// Polls [condition] until it's true or [timeout] elapses (fails loudly
/// via a thrown exception rather than hanging the test suite forever if
/// the provider never reaches the expected state).
Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWithValue(_userId),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> setCursor(
    String table, {
    required bool completed,
  }) async {
    await db
        .into(db.pullCursor)
        .insertOnConflictUpdate(
          PullCursorCompanion.insert(
            userId: _userId,
            syncTableName: table,
            initialPullCompleted: Value(completed),
          ),
        );
  }

  test('false when no PullCursor rows exist for the user', () async {
    final result = await container.read(initialPullCompleteProvider.future);
    expect(result, isFalse);
  });

  test(
    'false when one table is complete but the other isn\'t',
    () async {
      await setCursor('expense_control_items', completed: true);
      await setCursor('financial_transactions', completed: false);

      final result = await container.read(
        initialPullCompleteProvider.future,
      );
      expect(result, isFalse);
    },
  );

  test('true only when both tables are true', () async {
    await setCursor('expense_control_items', completed: true);
    await setCursor('financial_transactions', completed: true);

    final result = await container.read(initialPullCompleteProvider.future);
    expect(result, isTrue);
  });

  test(
    'updates reactively when the underlying PullCursor rows change',
    () async {
      final values = <bool>[];
      final subscription = container.listen(
        initialPullCompleteProvider,
        (previous, next) {
          final value = next.valueOrNull;
          if (value != null) values.add(value);
        },
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      // Let the stream's first (empty-cursor) emission land.
      expect(await container.read(initialPullCompleteProvider.future), isFalse);

      await setCursor('expense_control_items', completed: true);
      await setCursor('financial_transactions', completed: false);
      // Poll for the specific value expected, not a specific emission
      // COUNT — Drift's .watch() may coalesce or interleave emissions
      // across two back-to-back writes, so counting list length is
      // fragile; the values that DO arrive, and their final settled
      // state, are what this test actually needs to verify.
      await _waitUntil(() => values.isNotEmpty && values.last == false);
      expect(values.every((v) => v == false), isTrue);

      await setCursor('financial_transactions', completed: true);
      await _waitUntil(() => values.last == true);

      // Every emission before the last one must still be false — the
      // provider never reports "complete" before both tables actually are.
      expect(values.sublist(0, values.length - 1).every((v) => v == false), isTrue);
      expect(values.last, isTrue);
    },
  );
}
