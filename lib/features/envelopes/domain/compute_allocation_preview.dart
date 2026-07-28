import 'envelope.dart';

class AllocationPreviewLine {
  const AllocationPreviewLine({
    required this.envelope,
    required this.allocatedAmount,
    required this.resultingBalance,
  });

  final Envelope envelope;
  final int allocatedAmount;
  final int resultingBalance;

  bool get wouldBeNegative => resultingBalance < 0;
}

/// Result of previewing an allocation event (before it's confirmed).
///
/// Mirrors research.md §1's algorithm and the FR-011/FR-011a/FR-013
/// blocking conditions from spec.md's Clarifications.
class AllocationPreviewResult {
  const AllocationPreviewResult({
    required this.lines,
    required this.hasOverAllocation,
    required this.overAllocationExcess,
    required this.missingRoundingReceiver,
    required this.receiverEnvelopeId,
    required this.leftoverAddedToReceiver,
  });

  final List<AllocationPreviewLine> lines;

  /// FR-011a: combined fixed+percentage allocations exceed income entered.
  final bool hasOverAllocation;

  /// Only meaningful when [hasOverAllocation] is true.
  final int overAllocationExcess;

  /// FR-013: a nonzero leftover exists but no envelope is flagged as the
  /// rounding-remainder receiver.
  final bool missingRoundingReceiver;

  /// The envelope flagged as the rounding-remainder receiver, if any exists
  /// (independent of whether it actually received a leftover this event).
  final String? receiverEnvelopeId;

  /// The leftover amount folded into [receiverEnvelopeId]'s line this event
  /// (0 if there was no leftover, or if [missingRoundingReceiver] is true).
  /// Lets callers mark `AllocationEventLine.isRoundingRemainderLine`
  /// correctly without re-deriving this calculation (data-model.md).
  final int leftoverAddedToReceiver;

  /// FR-011: true if any envelope's resulting balance (existing balance +
  /// this event's allocation) would still be negative — relevant when an
  /// envelope already carries a negative balance from an unresolved
  /// overspend (see US2's no-other-envelope-to-cover edge case).
  bool get hasNegativeBalance => lines.any((line) => line.wouldBeNegative);

  bool get canConfirm =>
      !hasOverAllocation && !missingRoundingReceiver && !hasNegativeBalance;
}

/// Pure calculation, no side effects — see research.md §1 for the exact
/// algorithm this implements.
AllocationPreviewResult computeAllocationPreview({
  required int incomeAmount,
  required List<Envelope> envelopes,
}) {
  if (incomeAmount <= 0) {
    throw ArgumentError.value(
      incomeAmount,
      'incomeAmount',
      'must be > 0 (FR-029) — callers must reject non-positive income before '
          'invoking this preview, not rely on this exception for UI validation',
    );
  }

  final allocatedByEnvelopeId = <String, int>{};

  var fixedTotal = 0;
  for (final envelope in envelopes) {
    if (envelope.allocationMethod != AllocationMethod.fixed) continue;
    final amount = envelope.allocationValue.round();
    allocatedByEnvelopeId[envelope.id] = amount;
    fixedTotal += amount;
  }

  var percentageTotal = 0;
  for (final envelope in envelopes) {
    if (envelope.allocationMethod != AllocationMethod.percentage) continue;
    final rawShare = incomeAmount * envelope.allocationValue;
    final roundedShare = rawShare.round();
    allocatedByEnvelopeId[envelope.id] = roundedShare;
    percentageTotal += roundedShare;
  }

  final claimed = fixedTotal + percentageTotal;
  final leftover = incomeAmount - claimed;

  Envelope? receiver;
  for (final envelope in envelopes) {
    if (envelope.isRoundingReceiver) {
      receiver = envelope;
      break;
    }
  }

  var hasOverAllocation = false;
  var overAllocationExcess = 0;
  var missingRoundingReceiver = false;
  var leftoverAddedToReceiver = 0;

  if (leftover < 0) {
    hasOverAllocation = true;
    overAllocationExcess = -leftover;
  } else if (leftover > 0) {
    if (receiver != null) {
      allocatedByEnvelopeId[receiver.id] =
          (allocatedByEnvelopeId[receiver.id] ?? 0) + leftover;
      leftoverAddedToReceiver = leftover;
    } else {
      missingRoundingReceiver = true;
    }
  }

  final lines = [
    for (final envelope in envelopes)
      AllocationPreviewLine(
        envelope: envelope,
        allocatedAmount: allocatedByEnvelopeId[envelope.id] ?? 0,
        resultingBalance:
            envelope.balance + (allocatedByEnvelopeId[envelope.id] ?? 0),
      ),
  ];

  return AllocationPreviewResult(
    lines: lines,
    hasOverAllocation: hasOverAllocation,
    overAllocationExcess: overAllocationExcess,
    missingRoundingReceiver: missingRoundingReceiver,
    receiverEnvelopeId: receiver?.id,
    leftoverAddedToReceiver: leftoverAddedToReceiver,
  );
}
