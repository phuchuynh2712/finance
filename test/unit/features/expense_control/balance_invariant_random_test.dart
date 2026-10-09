import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/database/app_database.dart';
import 'package:finance/core/database/tables/financial_transactions_table.dart';
import 'package:finance/features/expense_control/data/expense_control_repository_impl.dart';
import 'package:finance/features/expense_control/data/transaction_correction_repository_impl.dart';
import 'package:finance/features/expense_control/domain/transaction_history_record.dart';
import 'package:finance/features/expenses/application/report_summary.dart';

import '../../../support/correction_fixtures.dart';

void main() {
  test('seeded transaction sequences preserve the balance invariant', () async {
    const baseSeed = 20261009;
    final start = DateTime(2000);
    final end = DateTime(3000);

    for (var sequence = 0; sequence < 200; sequence++) {
      final seed = baseSeed + sequence;
      final random = Random(seed);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      try {
        final items = [
          for (var index = 0; index < 4; index++)
            CorrectionItemSeed(
              id: 'item-$index',
              name: 'Item $index',
              balanceBase: 10000 + index,
              balance: 10000 + index,
            ),
        ];
        await seedLedger(db, items: items);
        final recordingRepository = ExpenseControlRepositoryImpl(
          db,
          userId: 'u1',
        );
        final correctionRepository = TransactionCorrectionRepositoryImpl(
          db,
          userId: 'u1',
        );
        final itemIds = items.map((item) => item.id).toList();
        for (var step = 0; step < 60; step++) {
          final operation = random.nextInt(5);
          if (operation == 0) {
            await recordingRepository.recordExpense(
              itemId: itemIds[random.nextInt(itemIds.length)],
              amount: random.nextInt(1000) + 1,
            );
          } else if (operation == 1) {
            final shuffledIds = [...itemIds]..shuffle(random);
            final shareCount = random.nextInt(itemIds.length) + 1;
            await recordingRepository.applyIncomeAllocation({
              for (final itemId in shuffledIds.take(shareCount))
                itemId: random.nextInt(1000) + 1,
            });
          } else {
            final rows = await db.select(db.financialTransactions).get();
            final liveOriginals = rows
                .where(
                  (row) =>
                      row.userId == 'u1' &&
                      row.deletedAt == null &&
                      row.reversesId == null &&
                      !rows.any(
                        (candidate) =>
                            candidate.reversesId == row.id &&
                            candidate.deletedAt == null,
                      ),
                )
                .toList();
            if (liveOriginals.isEmpty) {
              await recordingRepository.recordExpense(
                itemId: itemIds[random.nextInt(itemIds.length)],
                amount: random.nextInt(1000) + 1,
              );
            } else {
              final original =
                  liveOriginals[random.nextInt(liveOriginals.length)];
              final now = original.occurredAt.add(
                Duration(hours: operation == 4 ? 25 : 23),
              );
              switch (operation) {
                case 2:
                  await correctionRepository.delete(original.id, now: now);
                case 3:
                  if (original.direction == TransactionDirection.expense) {
                    await correctionRepository.editExpense(
                      original.id,
                      amount: random.nextInt(1000) + 1,
                      itemId: itemIds[random.nextInt(itemIds.length)],
                      now: now,
                    );
                  } else {
                    await correctionRepository.delete(original.id, now: now);
                  }
                case 4:
                  await correctionRepository.reverse(original.id, now: now);
              }
            }
          }

          final rows = await db.select(db.financialTransactions).get();
          final storedItems = await db.select(db.expenseControlItems).get();
          for (final item in storedItems) {
            final expectedBalance =
                item.balanceBase +
                rows
                    .where(
                      (row) =>
                          row.expenseControlItemId == item.id &&
                          row.userId == 'u1' &&
                          row.deletedAt == null,
                    )
                    .fold<int>(0, (total, row) {
                      final directionEffect =
                          row.direction == TransactionDirection.income
                          ? row.amount
                          : -row.amount;
                      return total +
                          (row.reversesId == null
                              ? directionEffect
                              : -directionEffect);
                    });
            expect(
              item.balance,
              expectedBalance,
              reason: 'seed=$seed, step=$step, item=${item.id}',
            );
          }

          final history = await recordingRepository
              .watchTransactionHistory(start: start, end: end)
              .first;
          final historyIds = history.map((record) => record.id).toSet();
          expect(
            rows
                .where((row) => row.deletedAt != null)
                .any((row) => historyIds.contains(row.id)),
            isFalse,
            reason: 'seed=$seed, step=$step: deleted rows must not be history',
          );
          final totals = computeReportTotals(history);
          expect(totals.totalIncome, greaterThanOrEqualTo(0));
          expect(totals.totalExpense, greaterThanOrEqualTo(0));
          expect(totals.refundedExpense, greaterThanOrEqualTo(0));
          expect(totals.withdrawnIncome, greaterThanOrEqualTo(0));
          expect(
            totals.totalExpense,
            history
                .where(
                  (record) =>
                      !record.isReversal &&
                      record.direction == TransactionHistoryDirection.expense,
                )
                .fold<int>(0, (total, record) => total + record.amount),
            reason: 'seed=$seed, step=$step: reversals are separate figures',
          );
          expect(
            totals.totalIncome,
            history
                .where(
                  (record) =>
                      !record.isReversal &&
                      record.direction == TransactionHistoryDirection.income,
                )
                .fold<int>(0, (total, record) => total + record.amount),
            reason: 'seed=$seed, step=$step: withdrawals are separate figures',
          );
        }
      } catch (error, stackTrace) {
        fail(
          'Randomized ledger invariant failed for seed=$seed: $error\n$stackTrace',
        );
      } finally {
        await db.close();
      }
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
