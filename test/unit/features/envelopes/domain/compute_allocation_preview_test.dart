import 'package:flutter_test/flutter_test.dart';

import 'package:finance/features/envelopes/domain/compute_allocation_preview.dart';
import 'package:finance/features/envelopes/domain/envelope.dart';

Envelope _fixed(
  String id,
  int amount, {
  int balance = 0,
  bool isRoundingReceiver = false,
}) {
  return Envelope(
    id: id,
    userId: 'u1',
    name: id,
    allocationMethod: AllocationMethod.fixed,
    allocationValue: amount.toDouble(),
    balance: balance,
    isRoundingReceiver: isRoundingReceiver,
  );
}

Envelope _percentage(
  String id,
  double fraction, {
  int balance = 0,
  bool isRoundingReceiver = false,
}) {
  return Envelope(
    id: id,
    userId: 'u1',
    name: id,
    allocationMethod: AllocationMethod.percentage,
    allocationValue: fraction,
    balance: balance,
    isRoundingReceiver: isRoundingReceiver,
  );
}

void main() {
  group('computeAllocationPreview', () {
    test(
      'fixed and percentage envelopes are computed independently against full income (FR-004/FR-005)',
      () {
        final result = computeAllocationPreview(
          incomeAmount: 20000000,
          envelopes: [
            _fixed('rent', 5000000),
            _percentage('savings', 0.30),
            _percentage('buffer', 0.0, isRoundingReceiver: true),
          ],
        );

        final rent = result.lines.firstWhere((l) => l.envelope.id == 'rent');
        final savings = result.lines.firstWhere(
          (l) => l.envelope.id == 'savings',
        );

        expect(rent.allocatedAmount, 5000000);
        // 30% of the FULL 20,000,000 income, independent of the rent deduction.
        expect(savings.allocatedAmount, 6000000);
      },
    );

    test(
      'leftover (rounding dust or unclaimed income) flows entirely to the flagged receiver, sum exactly equals income (FR-006/FR-007, SC-002)',
      () {
        final result = computeAllocationPreview(
          incomeAmount: 20000000,
          envelopes: [
            _fixed('rent', 5000000),
            _percentage('savings', 0.30),
            _percentage('buffer', 0.0, isRoundingReceiver: true),
          ],
        );

        final buffer = result.lines.firstWhere(
          (l) => l.envelope.id == 'buffer',
        );
        // 20,000,000 - 5,000,000 (rent) - 6,000,000 (savings) = 9,000,000 leftover.
        expect(buffer.allocatedAmount, 9000000);

        final totalAllocated = result.lines.fold<int>(
          0,
          (sum, line) => sum + line.allocatedAmount,
        );
        expect(totalAllocated, 20000000);
        expect(result.canConfirm, isTrue);
      },
    );

    test('percentage rounding uses round-half-up to the nearest whole VND', () {
      // 100,000 split three ways at 33.3...% each produces fractional shares;
      // rounding dust must land entirely on the receiver, not be dropped.
      final result = computeAllocationPreview(
        incomeAmount: 100000,
        envelopes: [
          _percentage('a', 1 / 3),
          _percentage('b', 1 / 3),
          _percentage('c', 1 / 3, isRoundingReceiver: true),
        ],
      );

      final totalAllocated = result.lines.fold<int>(
        0,
        (sum, line) => sum + line.allocatedAmount,
      );
      expect(totalAllocated, 100000);
    });

    test(
      'blocks confirmation when a nonzero leftover exists but no envelope is flagged as receiver (FR-013) — distinct from over-allocation',
      () {
        final result = computeAllocationPreview(
          incomeAmount: 20000000,
          envelopes: [
            _fixed('rent', 5000000),
            _percentage('savings', 0.30),
            // No envelope flagged as rounding receiver.
          ],
        );

        expect(result.missingRoundingReceiver, isTrue);
        expect(result.hasOverAllocation, isFalse);
        expect(result.canConfirm, isFalse);
      },
    );

    test(
      'detects over-allocation when combined fixed+percentage exceeds income, even with no single envelope negative (FR-011a)',
      () {
        final result = computeAllocationPreview(
          incomeAmount: 5000000,
          envelopes: [
            _fixed('rent', 5000000),
            _percentage('savings', 0.60),
            _percentage('fun', 0.60, isRoundingReceiver: true),
          ],
        );

        // Claimed = 5,000,000 (rent) + 3,000,000 (savings) + 3,000,000 (fun) = 11,000,000 > 5,000,000 income.
        expect(result.hasOverAllocation, isTrue);
        expect(result.overAllocationExcess, 6000000);
        expect(result.canConfirm, isFalse);
      },
    );

    test(
      'detects a resulting negative balance when an envelope already carries a negative balance the event does not fully offset (FR-011)',
      () {
        final result = computeAllocationPreview(
          incomeAmount: 1000000,
          envelopes: [
            _percentage(
              'groceries',
              0.10,
              balance: -200000,
            ), // allocated 100,000, resulting -100,000
            _percentage('buffer', 0.90, isRoundingReceiver: true),
          ],
        );

        final groceries = result.lines.firstWhere(
          (l) => l.envelope.id == 'groceries',
        );
        expect(groceries.resultingBalance, -100000);
        expect(result.hasNegativeBalance, isTrue);
        expect(result.canConfirm, isFalse);
      },
    );

    test('rejects zero or negative income (FR-029)', () {
      expect(
        () => computeAllocationPreview(incomeAmount: 0, envelopes: []),
        throwsArgumentError,
      );
      expect(
        () => computeAllocationPreview(incomeAmount: -1, envelopes: []),
        throwsArgumentError,
      );
    });
  });
}
