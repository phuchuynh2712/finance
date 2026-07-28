/// A single confirmed "Plan" action (spec Key Entities). Immutable once
/// created — no update/delete path exists anywhere in this feature.
class AllocationEvent {
  const AllocationEvent({
    required this.id,
    required this.userId,
    required this.eventDate,
    required this.incomeAmount,
  });

  final String id;
  final String userId;
  final DateTime eventDate;
  final int incomeAmount;
}
