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
  });

  final String id;
  final String sourceItemId;
  final TransactionHistoryDirection direction;
  final int amount;
  final DateTime occurredAt;
  final String displayName;
  final String? displayGroupName;
  final String? displayIconKey;
}
