import 'allocation_event.dart';
import 'allocation_event_line.dart';

abstract interface class AllocationRepository {
  /// Persists [event] and its [lines] (from an already-computed, confirmed
  /// [AllocationPreviewResult]) and applies each line's amount to its
  /// envelope's balance — all in one transaction, per the constitution's
  /// Offline-First mandate. No update/delete method exists: allocation
  /// events are immutable once confirmed (spec Key Entities).
  Future<void> confirmEvent({
    required AllocationEvent event,
    required List<AllocationEventLine> lines,
  });
}
