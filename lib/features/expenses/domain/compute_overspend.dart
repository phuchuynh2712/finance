/// Result of checking whether an expense would overspend its target
/// envelope (FR-016).
class OverspendCheckResult {
  const OverspendCheckResult({
    required this.shortfall,
    required this.needsCoveringEnvelope,
  });

  /// 0 if the expense does not overspend the target envelope.
  final int shortfall;

  bool get isOverspend => shortfall > 0;

  /// True only when [isOverspend] and at least one other envelope exists to
  /// select as a coverer. When `false` despite [isOverspend], the
  /// covering-envelope step is skipped entirely and the expense saves with
  /// the target envelope going negative (FR-016's Clarifications addendum).
  final bool needsCoveringEnvelope;
}

/// Pure calculation — no side effects. [otherEnvelopesCount] is the number
/// of envelopes besides the target one available to select as a coverer.
OverspendCheckResult computeOverspend({
  required int expenseAmount,
  required int targetEnvelopeBalance,
  required int otherEnvelopesCount,
}) {
  if (expenseAmount <= 0) {
    throw ArgumentError.value(expenseAmount, 'expenseAmount', 'must be > 0');
  }

  final resultingBalance = targetEnvelopeBalance - expenseAmount;
  if (resultingBalance >= 0) {
    return const OverspendCheckResult(
      shortfall: 0,
      needsCoveringEnvelope: false,
    );
  }

  final shortfall = -resultingBalance;
  return OverspendCheckResult(
    shortfall: shortfall,
    needsCoveringEnvelope: otherEnvelopesCount > 0,
  );
}
