/// The per-envelope breakdown of one [AllocationEvent] (research.md §4) —
/// persisted per FR-010 even though no history UI exists yet.
class AllocationEventLine {
  const AllocationEventLine({
    required this.id,
    required this.userId,
    required this.allocationEventId,
    required this.envelopeId,
    required this.amount,
    required this.isRoundingRemainderLine,
  });

  final String id;
  final String userId;
  final String allocationEventId;
  final String envelopeId;
  final int amount;
  final bool isRoundingRemainderLine;
}
