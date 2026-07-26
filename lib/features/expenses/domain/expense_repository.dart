import 'expense_entry.dart';

abstract interface class ExpenseRepository {
  Stream<List<ExpenseEntry>> watchAll();

  /// Records a new expense, decreasing its target envelope's balance
  /// (FR-015). If [coveringEnvelopeId] is provided, the shortfall is also
  /// deducted from it and an `EnvelopeCoverage` record is created (FR-017).
  Future<void> create({
    required ExpenseEntry expense,
    String? coveringEnvelopeId,
  });

  /// Edits a previously saved expense. Internally reverses the original
  /// entry's balance and coverage effects before reapplying [expense]'s new
  /// values (FR-018a) — callers only need to supply the desired new state,
  /// not the prior one.
  Future<void> update({
    required ExpenseEntry expense,
    String? coveringEnvelopeId,
  });

  /// Deletes a previously saved expense, reversing its balance and any
  /// linked coverage effects (FR-018a).
  Future<void> delete(String id);
}
