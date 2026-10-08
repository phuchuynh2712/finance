import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:finance/core/database/app_database.dart';
import 'package:finance/core/database/tables/financial_transactions_table.dart';

/// The one place an item's balance is produced (research.md Decision 1).
///
/// `balance = balance_base + Σ effect(t)` over the item's live (not
/// soft-deleted) transactions, where the effect of a transaction is its
/// amount, positive for income and negative for expense, and negated for a
/// reversing entry. The server computes the same value in Postgres triggers,
/// so a device and the server agree whatever order the rows arrive in and
/// however many times one of them is applied: a recompute from the set of
/// rows is idempotent, a stream of deltas is not.
///
/// Every writer of transactions (the record flows, the corrections, and the
/// sync paths that apply a row from the server) calls [recomputeBalances]
/// for the items it touched, inside the same database transaction. Nothing
/// else may write `expense_control_items.balance`.
class BalanceLedger {
  const BalanceLedger._();

  /// The effect of one transaction on its item's balance.
  static int effectOf(
    TransactionDirection direction,
    int amount, {
    required bool isReversal,
  }) {
    final signed = switch (direction) {
      TransactionDirection.income => amount,
      TransactionDirection.expense => -amount,
    };
    return isReversal ? -signed : signed;
  }

  /// The SQL form of [effectOf] summed over an item's live rows: a signed
  /// amount by direction, negated for a reversal (`reverses_id` set).
  static const String _sumOfLiveEffects =
      '(SELECT SUM('
      "CASE direction WHEN 'income' THEN amount ELSE -amount END "
      '* CASE WHEN reverses_id IS NULL THEN 1 ELSE -1 END) '
      'FROM financial_transactions '
      'WHERE expense_control_item_id = expense_control_items.id '
      'AND deleted_at IS NULL)';

  /// Recomputes one item. `updated_at` and `server_balance` are left alone: a
  /// derived value is not a change to push, and the server's figure is only
  /// the server's.
  @visibleForTesting
  static const String recomputeSql =
      'UPDATE expense_control_items '
      'SET balance = balance_base + COALESCE($_sumOfLiveEffects, 0) '
      'WHERE id = ?';

  /// Recomputes the balance of each of [itemIds] (duplicates and unknown ids
  /// are harmless). `customUpdate` with `updates` rather than a raw statement
  /// so Drift's `.watch()` streams re-emit.
  static Future<void> recomputeBalances(
    AppDatabase db,
    Iterable<String> itemIds,
  ) async {
    for (final id in itemIds.toSet()) {
      await db.customUpdate(
        recomputeSql,
        variables: [Variable<String>(id)],
        updates: {db.expenseControlItems},
        updateKind: UpdateKind.update,
      );
    }
  }

  /// The upgrade to schema v8: makes `balance_base` the part of every item's
  /// balance that its live transactions do not explain, so that a recompute
  /// afterwards returns exactly the balance the item had (SC-006).
  static Future<void> backfillBalanceBase(AppDatabase db) async {
    await db.customStatement(
      'UPDATE expense_control_items '
      'SET balance_base = balance - COALESCE($_sumOfLiveEffects, 0)',
    );
  }

  /// Ids of live items whose server-reported balance differs from the derived
  /// one and that have no transaction waiting in the outbox (a waiting
  /// transaction explains the difference: the server has not seen it yet).
  /// The input of the reconciliation (FR-018).
  static Future<List<String>> findDivergent(AppDatabase db) async {
    final candidates =
        await (db.select(db.expenseControlItems)..where(
              (i) =>
                  i.deletedAt.isNull() &
                  i.serverBalance.isNotNull() &
                  i.serverBalance.equalsExp(i.balance).not(),
            ))
            .get();
    if (candidates.isEmpty) return const [];

    final waiting =
        await (db.select(db.syncOutbox)..where(
              (o) =>
                  o.entityTable.equals('financial_transactions') &
                  o.syncedAt.isNull() &
                  o.rejectedAt.isNull(),
            ))
            .get();
    final itemsWithWaitingTransactions = <String>{
      for (final entry in waiting)
        if ((jsonDecode(entry.payload)
                as Map<String, dynamic>)['expense_control_item_id']
            case final String itemId)
          itemId,
    };
    return [
      for (final item in candidates)
        if (!itemsWithWaitingTransactions.contains(item.id)) item.id,
    ];
  }
}
