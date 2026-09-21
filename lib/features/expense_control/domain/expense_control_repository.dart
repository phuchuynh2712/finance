import 'expense_control_item.dart';

/// See contracts/expense_control_repository.md for the full contract.
abstract interface class ExpenseControlRepository {
  /// Reactive flat list of the current user's non-deleted items (both
  /// top-level and children). Presentation assembles the tree from this
  /// stream via [ExpenseControlPlanService].
  Stream<List<ExpenseControlItem>> watchAll();

  Future<List<ExpenseControlItem>> getAll();

  /// Creates a top-level item or a child. If [item.parentId] is set and the
  /// parent currently has zero children, the parent's own formula is
  /// cleared in the same transaction (FR-004).
  Future<void> create(ExpenseControlItem item);

  /// Updates name/icon/description (immediate, via the edit dialog).
  /// Formula changes to an *existing* item go through [saveFormulas]
  /// instead (research.md §9). Does not change parentId.
  Future<void> update(ExpenseControlItem item);

  /// Soft-deletes [id]. If [id] is a group, also soft-deletes its direct
  /// children in the same transaction (FR-016).
  Future<void> delete(String id);

  /// Persists a new top-level display order (FR-014). [orderedIds] MUST
  /// contain exactly the current set of top-level item ids for this user.
  Future<void> reorderTopLevel(List<String> orderedIds);

  /// Batch-commits pending whole-item edits for existing items — the
  /// data-layer half of the "Lưu công thức" flow (data-model.md — widened
  /// from formula-only to also cover name/icon/description). Callers MUST
  /// validate the resulting full plan before calling this. A `null` field
  /// on a [PendingItemEdit] means "leave that field unchanged," not "clear
  /// it."
  Future<void> saveFormulas(Map<String, PendingItemEdit> changes);

  /// Adds each delta to the named item's existing `balance`, atomically, in
  /// one transaction with one sync_outbox row per changed item — the
  /// data-layer half of an income save (FR-005–FR-014). Deltas MUST already
  /// be non-negative (the allocation algorithm never produces a negative
  /// delta); this method does not itself validate that. Each increment MUST
  /// be applied as a single `balance = balance + delta` SQL statement, never
  /// a read-then-write pair, to avoid losing a concurrent write to the same
  /// row within the same local transaction window (see the implementation's
  /// own doc comment for why).
  Future<void> applyIncomeAllocation(Map<String, int> balanceDeltas);

  /// Atomically decrements [itemId]'s `balance` by [amount] and records one
  /// expense Financial Transaction row — the data-layer half of the "Chi
  /// tiêu" save flow (FR-009). [amount] MUST be `> 0`. The balance is
  /// allowed to go negative; this method never blocks or throws for that
  /// reason alone (FR-010) — negative balances are a warn-only UI concern,
  /// not a data-layer one.
  Future<void> recordExpense({required String itemId, required int amount});
}
