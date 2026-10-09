enum TransactionHistoryDirection { income, expense }

class TransactionHistoryRecord {
  const TransactionHistoryRecord({
    required this.id,
    required this.sourceItemId,
    required this.direction,
    required this.amount,
    required this.occurredAt,
    required this.displayName,
    required this.displayGroupName,
    required this.displayIconKey,
    this.reversesId,
    this.isReversed = false,
    this.reversedById,
  });

  final String id;
  final String sourceItemId;
  final TransactionHistoryDirection direction;
  final int amount;
  final DateTime occurredAt;
  final String displayName;
  final String? displayGroupName;
  final String? displayIconKey;

  /// Set only on a reversing entry: the id of the transaction it cancels. A
  /// reversal has the same direction, amount and item as that transaction and
  /// the opposite effect on the balance (spec FR-006).
  final String? reversesId;

  /// Whether a live reversing entry cancels this transaction. A reversed
  /// transaction stays in the history and can no longer be changed (FR-007).
  final bool isReversed;

  /// The live reversal row cancelling this record, when one exists.
  final String? reversedById;

  /// Whether this record is itself a reversing entry.
  bool get isReversal => reversesId != null;
}
