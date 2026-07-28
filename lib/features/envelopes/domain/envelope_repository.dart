import 'envelope.dart';

abstract interface class EnvelopeRepository {
  /// Reactive list of the current user's non-deleted envelopes.
  Stream<List<Envelope>> watchAll();

  Future<List<Envelope>> getAll();

  Future<void> create(Envelope envelope);

  /// Also enforces FR-002's exclusivity: if [envelope.isRoundingReceiver] is
  /// true, any other envelope currently holding that flag is cleared first.
  Future<void> update(Envelope envelope);

  /// Soft-deletes the envelope (per the offline-first tombstone pattern).
  /// Callers are responsible for the FR-027/FR-028 warning and
  /// receiver-reassignment flows before invoking this.
  Future<void> delete(String id);
}
