import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/database/app_database.dart';
import 'package:finance/core/database/tables/expense_control_items_table.dart';
import 'package:finance/core/database/tables/financial_transactions_table.dart';
import 'package:finance/core/di/expense_dependencies.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart'
    hide ExpenseAllocationMethod;
import 'package:finance/features/expense_control/domain/transaction_correction_repository.dart';
import 'package:finance/features/expense_control/domain/transaction_history_record.dart';
import 'package:finance/features/expense_control/domain/transaction_history_repository.dart';

import 'expense_control_fixtures.dart';
import 'pull_complete_override.dart';

class CorrectionItemSeed {
  const CorrectionItemSeed({
    required this.id,
    this.userId = 'u1',
    this.parentId,
    this.name = 'Current item name',
    this.iconKey = 'home',
    this.allocationMethod = ExpenseAllocationMethod.percentage,
    this.allocationValue = 10,
    this.balanceBase = 0,
    this.balance = 0,
    this.deletedAt,
  });

  final String id;
  final String userId;
  final String? parentId;
  final String name;
  final String iconKey;
  final ExpenseAllocationMethod? allocationMethod;
  final double? allocationValue;
  final int balanceBase;
  final int balance;
  final DateTime? deletedAt;
}

class CorrectionTransactionSeed {
  const CorrectionTransactionSeed({
    required this.id,
    required this.itemId,
    required this.direction,
    required this.amount,
    required this.occurredAt,
    this.userId = 'u1',
    this.displayName = 'Recorded item name',
    this.displayGroupName = 'Recorded group name',
    this.displayIconKey = 'home',
    this.reversesId,
    this.deletedAt,
  });

  final String id;
  final String itemId;
  final TransactionDirection direction;
  final int amount;
  final DateTime occurredAt;
  final String userId;
  final String? displayName;
  final String? displayGroupName;
  final String? displayIconKey;
  final String? reversesId;
  final DateTime? deletedAt;
}

/// Seeds the current v8 local ledger with explicit balance and transaction
/// state for correction repository and sync tests.
Future<void> seedLedger(
  AppDatabase db, {
  Iterable<CorrectionItemSeed> items = const [],
  Iterable<CorrectionTransactionSeed> transactions = const [],
}) async {
  for (final item in items) {
    await db
        .into(db.expenseControlItems)
        .insert(
          ExpenseControlItemsCompanion.insert(
            id: item.id,
            userId: item.userId,
            parentId: Value(item.parentId),
            name: item.name,
            iconKey: item.iconKey,
            allocationMethod: Value(item.allocationMethod),
            allocationValue: Value(item.allocationValue),
            balanceBase: Value(item.balanceBase),
            balance: Value(item.balance),
            deletedAt: Value(item.deletedAt),
          ),
        );
  }
  for (final transaction in transactions) {
    await db
        .into(db.financialTransactions)
        .insert(
          FinancialTransactionsCompanion.insert(
            id: transaction.id,
            userId: transaction.userId,
            expenseControlItemId: transaction.itemId,
            direction: transaction.direction,
            amount: transaction.amount,
            occurredAt: transaction.occurredAt,
            displayName: Value(transaction.displayName),
            displayGroupName: Value(transaction.displayGroupName),
            displayIconKey: Value(transaction.displayIconKey),
            reversesId: Value(transaction.reversesId),
            deletedAt: Value(transaction.deletedAt),
          ),
        );
  }
}

class FakeTransactionCorrectionRepository
    implements TransactionCorrectionRepository {
  CorrectionResult deleteResult = const CorrectionDone();
  CorrectionPreview deletePreview = const CorrectionPreview(
    amount: 0,
    items: [],
  );
  CorrectionPreview reversePreview = const CorrectionPreview(
    amount: 0,
    items: [],
  );
  Completer<void>? deleteGate;
  Completer<void>? reverseGate;
  final List<({String transactionId, DateTime now})> deleteCalls = [];
  final List<({String transactionId, DateTime now})> reverseCalls = [];
  CorrectionResult editResult = const CorrectionDone();
  Completer<void>? editGate;
  final List<({String transactionId, int amount, String itemId, DateTime now})>
  editCalls = [];

  @override
  Future<CorrectionResult> delete(
    String transactionId, {
    required DateTime now,
  }) async {
    deleteCalls.add((transactionId: transactionId, now: now));
    if (deleteGate case final gate?) await gate.future;
    return deleteResult;
  }

  @override
  Future<CorrectionPreview> previewDelete(String transactionId) async =>
      deletePreview;

  @override
  Future<CorrectionPreview> previewReverse(String transactionId) async =>
      reversePreview;

  @override
  Future<CorrectionResult> reverse(
    String transactionId, {
    required DateTime now,
  }) async {
    reverseCalls.add((transactionId: transactionId, now: now));
    if (reverseGate case final gate?) await gate.future;
    return editResult;
  }

  @override
  Future<CorrectionResult> editExpense(
    String transactionId, {
    required int amount,
    required String itemId,
    required DateTime now,
  }) async {
    editCalls.add((
      transactionId: transactionId,
      amount: amount,
      itemId: itemId,
      now: now,
    ));
    if (editGate case final gate?) await gate.future;
    return editResult;
  }
}

class FakeCorrectionHistoryRepository implements TransactionHistoryRepository {
  const FakeCorrectionHistoryRepository([this.records = const []]);

  final List<TransactionHistoryRecord> records;

  @override
  Stream<List<TransactionHistoryRecord>> watchTransactionHistory({
    required DateTime start,
    required DateTime end,
  }) {
    return Stream.value(
      records
          .where(
            (record) =>
                !record.occurredAt.isBefore(start) &&
                record.occurredAt.isBefore(end),
          )
          .toList(),
    );
  }

  @override
  Stream<List<TransactionHistoryRecord>> watchRecent({required int limit}) =>
      Stream.value(records.take(limit).toList());
}

class FakeCorrectionExpenseControlRepository
    extends FakeExpenseControlRepository
    implements TransactionHistoryLookup {
  FakeCorrectionExpenseControlRepository(super.items, this.records);

  final List<TransactionHistoryRecord> records;

  @override
  Future<TransactionHistoryRecord?> getTransactionById(
    String transactionId,
  ) async {
    for (final record in records) {
      if (record.id == transactionId) return record;
    }
    return null;
  }
}

Future<void> correctionHarness(
  WidgetTester tester, {
  required Widget child,
  required FakeTransactionCorrectionRepository correctionRepository,
  required FakeCorrectionHistoryRepository historyRepository,
  DateTime? now,
  List<ExpenseControlItem> items = const [],
  Locale locale = const Locale('vi'),
  double width = 412,
  double height = 915,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        transactionCorrectionRepositoryProvider.overrideWithValue(
          correctionRepository,
        ),
        expenseControlRepositoryProvider.overrideWithValue(
          FakeCorrectionExpenseControlRepository(
            items,
            historyRepository.records,
          ),
        ),
        correctionNowProvider.overrideWithValue(() => now ?? DateTime.now()),
        transactionHistoryRepositoryProvider.overrideWithValue(
          historyRepository,
        ),
        expenseControlItemsStreamProvider.overrideWith(
          (ref) => Stream.value(items),
        ),
        pullCompleteOverride,
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: child,
      ),
    ),
  );
}
