enum ExpenseMethod { manual, scanned }

/// A single spending transaction (spec Key Entities). Unlike Allocation
/// Event, may be edited or deleted after creation (FR-018a).
class ExpenseEntry {
  const ExpenseEntry({
    required this.id,
    required this.userId,
    required this.envelopeId,
    required this.amount,
    required this.entryDate,
    this.note,
    this.entryMethod = ExpenseMethod.manual,
  });

  final String id;
  final String userId;
  final String envelopeId;
  final int amount;
  final DateTime entryDate;
  final String? note;
  final ExpenseMethod entryMethod;
}
