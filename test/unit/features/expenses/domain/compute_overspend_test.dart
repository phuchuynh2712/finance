import 'package:flutter_test/flutter_test.dart';

import 'package:finance/features/expenses/domain/compute_overspend.dart';

void main() {
  group('computeOverspend', () {
    test('no overspend when the expense fits within the balance', () {
      final result = computeOverspend(
        expenseAmount: 500000,
        targetEnvelopeBalance: 2000000,
        otherEnvelopesCount: 3,
      );

      expect(result.isOverspend, isFalse);
      expect(result.shortfall, 0);
      expect(result.needsCoveringEnvelope, isFalse);
    });

    test(
      'detects overspend and requires a covering envelope when others exist (FR-016)',
      () {
        final result = computeOverspend(
          expenseAmount: 500000,
          targetEnvelopeBalance: 300000,
          otherEnvelopesCount: 1,
        );

        expect(result.isOverspend, isTrue);
        expect(result.shortfall, 200000);
        expect(result.needsCoveringEnvelope, isTrue);
      },
    );

    test(
      'skips the covering-envelope requirement when no other envelope exists (FR-016 Clarifications addendum)',
      () {
        final result = computeOverspend(
          expenseAmount: 500000,
          targetEnvelopeBalance: 300000,
          otherEnvelopesCount: 0,
        );

        expect(result.isOverspend, isTrue);
        expect(result.shortfall, 200000);
        expect(result.needsCoveringEnvelope, isFalse);
      },
    );

    test('an expense exactly equal to the balance is not an overspend', () {
      final result = computeOverspend(
        expenseAmount: 1000000,
        targetEnvelopeBalance: 1000000,
        otherEnvelopesCount: 2,
      );

      expect(result.isOverspend, isFalse);
    });

    test('rejects a non-positive expense amount', () {
      expect(
        () => computeOverspend(
          expenseAmount: 0,
          targetEnvelopeBalance: 1000000,
          otherEnvelopesCount: 1,
        ),
        throwsArgumentError,
      );
    });

    test(
      'editing a non-overspending expense upward can re-trigger overspend detection (FR-018a) — '
      'reversal (restore old amount) then re-check with the new amount, using the same pure function',
      () {
        // Saved expense: 300,000 against a 1,000,000 balance -> balance now 700,000.
        // Editing the amount up to 1,200,000: first reverse (700,000 + 300,000 = 1,000,000),
        // then re-run the overspend check against the NEW amount.
        const balanceAfterOriginalExpense = 700000;
        const originalAmount = 300000;
        const restoredBalance = balanceAfterOriginalExpense + originalAmount;

        final result = computeOverspend(
          expenseAmount: 1200000,
          targetEnvelopeBalance: restoredBalance,
          otherEnvelopesCount: 1,
        );

        expect(result.isOverspend, isTrue);
        expect(result.shortfall, 200000);
        expect(result.needsCoveringEnvelope, isTrue);
      },
    );
  });
}
