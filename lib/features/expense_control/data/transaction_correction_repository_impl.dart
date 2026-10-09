import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:finance/core/database/app_database.dart';
import 'package:finance/core/database/balance_ledger.dart';
import 'package:finance/core/database/tables/financial_transactions_table.dart';
import 'package:finance/core/sync/sync_outbox_table.dart';
import 'package:finance/features/expense_control/domain/transaction_correction_policy.dart';
import 'package:finance/features/expense_control/domain/transaction_correction_repository.dart';

import 'package:finance/features/expense_control/data/ledger_writes.dart';

/// Applies transaction corrections atomically to the local ledger and outbox.
class TransactionCorrectionRepositoryImpl
    implements TransactionCorrectionRepository {
  TransactionCorrectionRepositoryImpl(
    this._db, {
    required String userId,
    void Function()? onCommitted,
  }) : _userId = userId,
       _onCommitted = onCommitted;

  static const _uuid = Uuid();

  final AppDatabase _db;
  final String _userId;
  final void Function()? _onCommitted;
  late final LedgerWrites _writes = LedgerWrites(_db);

  @override
  Future<CorrectionResult> delete(
    String transactionId, {
    required DateTime now,
  }) async {
    final result = await _db.transaction(() async {
      final target = await _findOwnedLiveTransaction(transactionId);
      if (target == null) {
        return const CorrectionNotAllowed(CorrectionDenial.notFound);
      }
      if (target.reversesId != null) {
        return const CorrectionNotAllowed(CorrectionDenial.isReversal);
      }
      if (await _hasLiveReversal(target.id)) {
        return const CorrectionNotAllowed(CorrectionDenial.alreadyReversed);
      }
      if (!TransactionCorrectionPolicy.isInsideWindow(target.occurredAt, now)) {
        return const CorrectionNotAllowed(CorrectionDenial.windowEnded);
      }

      final rows = await _rowsInCorrectionEvent(target);
      for (final row in rows) {
        if (await _hasLiveReversal(row.id)) {
          return const CorrectionNotAllowed(CorrectionDenial.alreadyReversed);
        }
      }
      final touchedItemIds = rows
          .map((row) => row.expenseControlItemId)
          .toSet();
      final availableItemIds = await _liveItemIds(touchedItemIds);
      for (final row in rows) {
        final updatedAt = _nextTimestamp(now, row.updatedAt);
        await (_db.update(
          _db.financialTransactions,
        )..where((table) => table.id.equals(row.id))).write(
          FinancialTransactionsCompanion(
            deletedAt: Value(now),
            updatedAt: Value(updatedAt),
          ),
        );
        final deleted = await (_db.select(
          _db.financialTransactions,
        )..where((table) => table.id.equals(row.id))).getSingle();
        await _writes.appendOutbox(
          deleted.id,
          SyncOperation.update,
          _writes.transactionPayload(deleted),
          entityTable: 'financial_transactions',
        );
      }
      await BalanceLedger.recomputeBalances(_db, availableItemIds);
      return CorrectionDone(
        itemsWithoutBalance: touchedItemIds
            .difference(availableItemIds)
            .toList(),
      );
    });

    if (result is CorrectionDone) _onCommitted?.call();
    return result;
  }

  @override
  Future<CorrectionResult> editExpense(
    String transactionId, {
    required int amount,
    required String itemId,
    required DateTime now,
  }) async {
    final result = await _db.transaction(() async {
      final target = await _findOwnedLiveTransaction(transactionId);
      if (target == null) {
        return const CorrectionNotAllowed(CorrectionDenial.notFound);
      }
      if (target.reversesId != null) {
        return const CorrectionNotAllowed(CorrectionDenial.isReversal);
      }
      if (target.direction != TransactionDirection.expense) {
        return const CorrectionNotAllowed(CorrectionDenial.notEditable);
      }
      if (await _hasLiveReversal(target.id)) {
        return const CorrectionNotAllowed(CorrectionDenial.alreadyReversed);
      }
      if (!TransactionCorrectionPolicy.isInsideWindow(target.occurredAt, now)) {
        return const CorrectionNotAllowed(CorrectionDenial.windowEnded);
      }
      if (amount <= 0) {
        return const CorrectionNotAllowed(CorrectionDenial.invalidAmount);
      }

      final newItem = await _findLiveLeafItem(itemId);
      if (newItem == null) {
        return const CorrectionNotAllowed(CorrectionDenial.itemRemoved);
      }
      final groupName = await _groupNameFor(newItem);
      final updatedAt = _nextTimestamp(now, target.updatedAt);
      await (_db.update(
        _db.financialTransactions,
      )..where((row) => row.id.equals(target.id))).write(
        FinancialTransactionsCompanion(
          amount: Value(amount),
          expenseControlItemId: Value(itemId),
          displayName: Value(newItem.name),
          displayGroupName: Value(groupName),
          displayIconKey: Value(newItem.iconKey),
          updatedAt: Value(updatedAt),
        ),
      );
      final updated = await (_db.select(
        _db.financialTransactions,
      )..where((row) => row.id.equals(target.id))).getSingle();
      await _writes.appendOutbox(
        updated.id,
        SyncOperation.update,
        _writes.transactionPayload(updated),
        entityTable: 'financial_transactions',
      );

      final touchedItemIds = {target.expenseControlItemId, itemId};
      final availableItemIds = await _liveItemIds(touchedItemIds);
      await BalanceLedger.recomputeBalances(_db, availableItemIds);
      return CorrectionDone(
        itemsWithoutBalance: touchedItemIds
            .difference(availableItemIds)
            .toList(),
      );
    });

    if (result is CorrectionDone) _onCommitted?.call();
    return result;
  }

  @override
  Future<CorrectionResult> reverse(
    String transactionId, {
    required DateTime now,
  }) async {
    final result = await _db.transaction(() async {
      final target = await _findOwnedLiveTransaction(transactionId);
      if (target == null) {
        return const CorrectionNotAllowed(CorrectionDenial.notFound);
      }
      if (target.reversesId != null) {
        return const CorrectionNotAllowed(CorrectionDenial.isReversal);
      }
      if (await _hasLiveReversal(target.id)) {
        return const CorrectionNotAllowed(CorrectionDenial.alreadyReversed);
      }
      if (TransactionCorrectionPolicy.isInsideWindow(target.occurredAt, now)) {
        return const CorrectionNotAllowed(CorrectionDenial.windowStillOpen);
      }

      final rows = await _rowsInCorrectionEvent(target);
      for (final row in rows) {
        if (await _hasLiveReversal(row.id)) {
          return const CorrectionNotAllowed(CorrectionDenial.alreadyReversed);
        }
      }
      final touchedItemIds = rows
          .map((row) => row.expenseControlItemId)
          .toSet();
      final availableItemIds = await _liveItemIds(touchedItemIds);
      for (final row in rows) {
        final reversal = await _db
            .into(_db.financialTransactions)
            .insertReturning(
              FinancialTransactionsCompanion.insert(
                id: _uuid.v4(),
                userId: _userId,
                expenseControlItemId: row.expenseControlItemId,
                direction: row.direction,
                amount: row.amount,
                occurredAt: now,
                displayName: Value(row.displayName),
                displayGroupName: Value(row.displayGroupName),
                displayIconKey: Value(row.displayIconKey),
                reversesId: Value(row.id),
                updatedAt: Value(now),
              ),
            );
        await _writes.appendOutbox(
          reversal.id,
          SyncOperation.insert,
          _writes.transactionPayload(reversal),
          entityTable: 'financial_transactions',
        );
      }
      await BalanceLedger.recomputeBalances(_db, availableItemIds);
      return CorrectionDone(
        itemsWithoutBalance: touchedItemIds
            .difference(availableItemIds)
            .toList(),
      );
    });

    if (result is CorrectionDone) _onCommitted?.call();
    return result;
  }

  @override
  Future<CorrectionPreview> previewDelete(String transactionId) async {
    final target = await _findOwnedLiveTransaction(transactionId);
    if (target == null) {
      throw StateError('Cannot preview deletion of a missing transaction.');
    }
    if (target.reversesId != null) {
      throw StateError('Cannot preview deletion of a reversal transaction.');
    }

    final rows = await _rowsInCorrectionEvent(target);
    final effectsByItem = <String, int>{};
    for (final row in rows) {
      effectsByItem.update(
        row.expenseControlItemId,
        (effect) =>
            effect +
            BalanceLedger.effectOf(
              row.direction,
              row.amount,
              isReversal: false,
            ),
        ifAbsent: () => BalanceLedger.effectOf(
          row.direction,
          row.amount,
          isReversal: false,
        ),
      );
    }

    final itemIds = effectsByItem.keys.toSet();
    final items = await (_db.select(
      _db.expenseControlItems,
    )..where((row) => row.id.isIn(itemIds))).get();
    final itemsById = {for (final item in items) item.id: item};
    return CorrectionPreview(
      amount: target.amount,
      items: [
        for (final entry in effectsByItem.entries)
          _previewItem(
            entry.key,
            entry.value,
            itemsById[entry.key],
            rows.firstWhere((row) => row.expenseControlItemId == entry.key),
          ),
      ],
    );
  }

  @override
  Future<CorrectionPreview> previewReverse(String transactionId) async {
    final target = await _findOwnedLiveTransaction(transactionId);
    if (target == null) {
      throw StateError('Cannot preview reversal of a missing transaction.');
    }
    if (target.reversesId != null) {
      throw StateError('Cannot preview reversal of a reversal transaction.');
    }

    final rows = await _rowsInCorrectionEvent(target);
    final effectsByItem = <String, int>{};
    for (final row in rows) {
      effectsByItem.update(
        row.expenseControlItemId,
        (effect) =>
            effect +
            BalanceLedger.effectOf(row.direction, row.amount, isReversal: true),
        ifAbsent: () =>
            BalanceLedger.effectOf(row.direction, row.amount, isReversal: true),
      );
    }

    final itemIds = effectsByItem.keys.toSet();
    final items = await (_db.select(
      _db.expenseControlItems,
    )..where((row) => row.id.isIn(itemIds))).get();
    final itemsById = {for (final item in items) item.id: item};
    return CorrectionPreview(
      amount: target.amount,
      items: [
        for (final entry in effectsByItem.entries)
          _previewReverseItem(
            entry.key,
            entry.value,
            itemsById[entry.key],
            rows.firstWhere((row) => row.expenseControlItemId == entry.key),
          ),
      ],
    );
  }

  CorrectionPreviewItem _previewReverseItem(
    String itemId,
    int reversalEffect,
    ExpenseControlItemRow? item,
    FinancialTransactionRow recordedRow,
  ) {
    final removed = item == null || item.deletedAt != null;
    return CorrectionPreviewItem(
      itemId: itemId,
      itemName: removed
          ? recordedRow.displayName ?? recordedRow.expenseControlItemId
          : item.name,
      balanceAfter: removed ? 0 : item.balance + reversalEffect,
      itemRemoved: removed,
    );
  }

  Future<FinancialTransactionRow?> _findOwnedLiveTransaction(
    String transactionId,
  ) {
    return (_db.select(_db.financialTransactions)..where(
          (row) =>
              row.id.equals(transactionId) &
              row.userId.equals(_userId) &
              row.deletedAt.isNull(),
        ))
        .getSingleOrNull();
  }

  Future<bool> _hasLiveReversal(String transactionId) async {
    final reversal =
        await (_db.select(_db.financialTransactions)
              ..where(
                (row) =>
                    row.reversesId.equals(transactionId) &
                    row.userId.equals(_userId) &
                    row.deletedAt.isNull(),
              )
              ..limit(1))
            .getSingleOrNull();
    return reversal != null;
  }

  Future<List<FinancialTransactionRow>> _rowsInCorrectionEvent(
    FinancialTransactionRow target,
  ) async {
    if (target.direction != TransactionDirection.income) return [target];
    return (_db.select(_db.financialTransactions)..where(
          (row) =>
              row.userId.equals(_userId) &
              row.direction.equalsValue(TransactionDirection.income) &
              row.occurredAt.equals(target.occurredAt) &
              row.reversesId.isNull() &
              row.deletedAt.isNull(),
        ))
        .get();
  }

  Future<Set<String>> _liveItemIds(Set<String> itemIds) async {
    if (itemIds.isEmpty) return const {};
    final rows = await (_db.select(
      _db.expenseControlItems,
    )..where((row) => row.id.isIn(itemIds) & row.deletedAt.isNull())).get();
    return {for (final row in rows) row.id};
  }

  Future<ExpenseControlItemRow?> _findLiveLeafItem(String itemId) async {
    final item =
        await (_db.select(_db.expenseControlItems)..where(
              (row) =>
                  row.id.equals(itemId) &
                  row.userId.equals(_userId) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (item == null || item.allocationMethod == null) return null;
    final child =
        await (_db.select(_db.expenseControlItems)
              ..where(
                (row) =>
                    row.parentId.equals(itemId) &
                    row.userId.equals(_userId) &
                    row.deletedAt.isNull(),
              )
              ..limit(1))
            .getSingleOrNull();
    return child == null ? item : null;
  }

  Future<String> _groupNameFor(ExpenseControlItemRow item) async {
    final parentId = item.parentId;
    if (parentId == null) return item.name;
    final parent =
        await (_db.select(_db.expenseControlItems)..where(
              (row) =>
                  row.id.equals(parentId) &
                  row.userId.equals(_userId) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    return parent?.name ?? item.name;
  }

  CorrectionPreviewItem _previewItem(
    String itemId,
    int currentEffect,
    ExpenseControlItemRow? item,
    FinancialTransactionRow recordedRow,
  ) {
    final removed = item == null || item.deletedAt != null;
    return CorrectionPreviewItem(
      itemId: itemId,
      itemName: removed
          ? recordedRow.displayName ?? recordedRow.expenseControlItemId
          : item.name,
      balanceAfter: removed ? 0 : item.balance - currentEffect,
      itemRemoved: removed,
    );
  }

  DateTime _nextTimestamp(DateTime now, DateTime previous) {
    if (now.isAfter(previous)) return now;
    return previous.add(const Duration(microseconds: 1));
  }
}
