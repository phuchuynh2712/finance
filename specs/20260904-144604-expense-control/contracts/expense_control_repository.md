# Contract: `ExpenseControlRepository` (domain interface)

This feature has no external/HTTP API — its only "contract" is the internal domain-layer interface (`lib/features/expense_control/domain/expense_control_repository.dart`) that the presentation layer depends on and that the data layer implements, per the Constitution's Clean Architecture layering. This mirrors `EnvelopeRepository` (`lib/features/envelopes/domain/envelope_repository.dart`).

```dart
abstract interface class ExpenseControlRepository {
  /// Reactive flat list of the current user's non-deleted items (both
  /// top-level and children). Presentation assembles the tree (see
  /// data-model.md's ExpenseControlNode) from this stream.
  Stream<List<ExpenseControlItem>> watchAll();

  Future<List<ExpenseControlItem>> getAll();

  /// Creates a top-level item or a child. If [item.parentId] is set and the
  /// parent currently has zero children, the parent's own formula
  /// (allocationMethod/allocationValue) is cleared in the same transaction
  /// (FR-004) — mirrors EnvelopeRepositoryImpl's single-transaction side
  /// effects (e.g. _clearExistingReceiver).
  Future<void> create(ExpenseControlItem item);

  /// Updates name/icon/description (immediate, via the edit dialog).
  /// Formula (allocationMethod/allocationValue) changes to an *existing*
  /// item go through [saveFormulas] instead, not this method (research.md
  /// §9) — [update] MAY still carry the item's current formula fields
  /// unchanged for convenience, but callers MUST NOT use it to change them.
  /// Does not change parentId (moving an item between groups/top-level is
  /// out of scope).
  Future<void> update(ExpenseControlItem item);

  /// Soft-deletes [id]. If [id] is a group, also soft-deletes its direct
  /// children in the same transaction (FR-016). Caller is responsible for
  /// the confirmation prompt before invoking this.
  Future<void> delete(String id);

  /// Persists a new top-level display order (FR-014). [orderedIds] MUST
  /// contain exactly the current set of top-level item ids for this user;
  /// children are unaffected.
  Future<void> reorderTopLevel(List<String> orderedIds);

  /// Batch-commits pending formula (allocationMethod/allocationValue) edits
  /// for existing items — the data-layer half of the "Lưu công thức" flow
  /// (research.md §9, resolving analyze finding G1). All entries in
  /// [changes] (itemId → new method/value) are written in a single Drift
  /// transaction with one sync_outbox row per changed item; nothing is
  /// written if the transaction fails partway. Does NOT itself validate
  /// FR-007/FR-008 — the caller (presentation layer, via
  /// ExpenseControlPlanService) MUST validate the resulting full plan
  /// before calling this, per the pre-conditions below.
  Future<void> saveFormulas(Map<String, ExpenseFormulaEdit> changes);
}

/// A pending formula edit: the new allocation mode/value for one item,
/// staged in presentation-layer state until "Lưu công thức" commits it.
class ExpenseFormulaEdit {
  const ExpenseFormulaEdit({required this.method, required this.value});
  final ExpenseAllocationMethod method;
  final double value;
}
```

## Pre-conditions the presentation layer MUST enforce before calling `create`/`update`

These are validated by the pure-Dart domain service (research.md §5), not by the repository, so invalid state never reaches this contract:

- `name` non-blank (FR-017).
- `allocationValue` non-zero, non-negative, non-blank when the item is (or will become) a leaf (FR-017).
- Percentage budget (FR-007/FR-008) holds across the user's entire plan *including* this candidate write.

## Pre-conditions for `saveFormulas`

The presentation layer MUST validate the *merged* plan (persisted items with the pending `changes` overlaid) against FR-007/FR-008 via `ExpenseControlPlanService` before calling `saveFormulas`, and MUST block the "Lưu công thức" action instead of calling it if validation fails (FR-012) — exactly the same block-before-persist contract as `create`/`update`, just evaluated against a batch instead of one item.

## Errors

The repository does not raise domain-specific validation exceptions — by the time it's called, the caller has already validated. Only Drift/storage-layer exceptions (e.g. constraint violations from concurrent modification) propagate, exactly as `EnvelopeRepositoryImpl` does today.
