/// Records an overspend resolution — a cross-envelope transfer (spec Key
/// Entities). Reversed automatically when its linked [ExpenseEntry] is
/// edited or deleted (FR-018a).
class EnvelopeCoverage {
  const EnvelopeCoverage({
    required this.id,
    required this.userId,
    required this.expenseEntryId,
    required this.sourceEnvelopeId,
    required this.coveringEnvelopeId,
    required this.amount,
    required this.coveredAt,
  });

  final String id;
  final String userId;
  final String expenseEntryId;
  final String sourceEnvelopeId;
  final String coveringEnvelopeId;
  final int amount;
  final DateTime coveredAt;
}
