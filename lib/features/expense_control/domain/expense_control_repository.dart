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

  /// Batch-commits pending formula edits for existing items — the
  /// data-layer half of the "Lưu công thức" flow (research.md §9). Callers
  /// MUST validate the resulting full plan before calling this.
  Future<void> saveFormulas(Map<String, ExpenseFormulaEdit> changes);
}
