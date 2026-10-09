import 'package:flutter_test/flutter_test.dart';

import 'package:finance/features/expense_control/domain/transaction_correction_policy.dart';
import 'package:finance/features/expense_control/domain/transaction_history_record.dart';

void main() {
  group('TransactionCorrectionPolicy.isInsideWindow', () {
    final occurredAt = DateTime(2026, 10, 8, 10);

    test('includes a transaction until one millisecond before 24 hours', () {
      expect(
        TransactionCorrectionPolicy.isInsideWindow(
          occurredAt,
          occurredAt.add(const Duration(hours: 24) - Duration(milliseconds: 1)),
        ),
        isTrue,
      );
    });

    test('excludes a transaction at exactly 24 hours', () {
      expect(
        TransactionCorrectionPolicy.isInsideWindow(
          occurredAt,
          occurredAt.add(const Duration(hours: 24)),
        ),
        isFalse,
      );
    });

    test('treats a future transaction as inside the window', () {
      expect(
        TransactionCorrectionPolicy.isInsideWindow(
          occurredAt,
          occurredAt.subtract(const Duration(minutes: 1)),
        ),
        isTrue,
      );
    });
  });

  group('TransactionCorrectionPolicy.availableActions', () {
    final now = DateTime(2026, 10, 9, 10);
    final recent = now.subtract(const Duration(hours: 1));
    final old = now.subtract(const Duration(hours: 25));

    TransactionHistoryRecord record(
      String id, {
      TransactionHistoryDirection direction =
          TransactionHistoryDirection.expense,
      DateTime? occurredAt,
      String? reversesId,
      bool isReversed = false,
    }) {
      return TransactionHistoryRecord(
        id: id,
        sourceItemId: 'item-1',
        direction: direction,
        amount: 100,
        occurredAt: occurredAt ?? recent,
        displayName: 'Groceries',
        displayGroupName: 'Living',
        displayIconKey: 'basket',
        reversesId: reversesId,
        isReversed: isReversed,
      );
    }

    test('recent expense can be deleted or edited', () {
      expect(
        TransactionCorrectionPolicy.availableActions(record('expense'), now),
        {CorrectionAction.delete, CorrectionAction.edit},
      );
    });

    test('recent income entry can only be deleted', () {
      expect(
        TransactionCorrectionPolicy.availableActions(
          record('income', direction: TransactionHistoryDirection.income),
          now,
        ),
        {CorrectionAction.delete},
      );
    });

    test('old live expense can only be reversed', () {
      expect(
        TransactionCorrectionPolicy.availableActions(
          record('expense', occurredAt: old),
          now,
        ),
        {CorrectionAction.reverse},
      );
    });

    test('old income entry can only be reversed', () {
      expect(
        TransactionCorrectionPolicy.availableActions(
          record(
            'income',
            direction: TransactionHistoryDirection.income,
            occurredAt: old,
          ),
          now,
        ),
        {CorrectionAction.reverse},
      );
    });

    test(
      'a reversed original offers no action inside or outside the window',
      () {
        expect(
          TransactionCorrectionPolicy.availableActions(
            record('reversed-recent', isReversed: true),
            now,
          ),
          isEmpty,
        );
        expect(
          TransactionCorrectionPolicy.availableActions(
            record('reversed-old', occurredAt: old, isReversed: true),
            now,
          ),
          isEmpty,
        );
      },
    );

    test('a reversal row offers no action inside or outside the window', () {
      expect(
        TransactionCorrectionPolicy.availableActions(
          record('reversal-recent', reversesId: 'original'),
          now,
        ),
        isEmpty,
      );
      expect(
        TransactionCorrectionPolicy.availableActions(
          record('reversal-old', occurredAt: old, reversesId: 'original'),
          now,
        ),
        isEmpty,
      );
    });
  });
}
