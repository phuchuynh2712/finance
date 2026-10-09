/// Why a correction was not made. Nothing is written when one is returned.
enum CorrectionDenial {
  /// The transaction is more than 24 hours old: it can only be reversed.
  windowEnded,

  /// The transaction is still inside the correction window: it is deleted or
  /// edited, not reversed.
  windowStillOpen,

  /// A reversing entry already cancels it.
  alreadyReversed,

  /// It is itself a reversing entry, which can never be changed.
  isReversal,

  /// The item it should be charged to is no longer in the plan.
  itemRemoved,

  /// The new amount is not greater than zero.
  invalidAmount,

  /// An income entry cannot be edited, only taken back as a whole.
  notEditable,

  /// There is no such transaction for this person (or it is already deleted).
  notFound,
}

/// The outcome of a correction (spec FR-003, FR-004, FR-006).
sealed class CorrectionResult {
  const CorrectionResult();
}

/// The correction was made, in one step with the balances.
final class CorrectionDone extends CorrectionResult {
  const CorrectionDone({this.itemsWithoutBalance = const []});

  /// Ids of the items the transaction was charged to that are no longer in the
  /// plan: they have no balance to restore (FR-012).
  final List<String> itemsWithoutBalance;
}

/// The correction was refused for [denial]; nothing changed.
final class CorrectionNotAllowed extends CorrectionResult {
  const CorrectionNotAllowed(this.denial);

  final CorrectionDenial denial;
}

/// One item touched by a correction, for the confirmation.
class CorrectionPreviewItem {
  const CorrectionPreviewItem({
    required this.itemId,
    required this.itemName,
    required this.balanceAfter,
    required this.itemRemoved,
  });

  final String itemId;

  /// The item's current name (a renamed item shows its new name), or the name
  /// recorded with the transaction when the item is gone.
  final String itemName;

  /// What the item's balance will be after the correction; meaningless when
  /// [itemRemoved].
  final int balanceAfter;

  /// The item is no longer in the plan, so there is no balance to restore.
  final bool itemRemoved;
}

/// What a correction would do, shown before the person confirms (FR-008).
class CorrectionPreview {
  const CorrectionPreview({required this.amount, required this.items});

  /// The amount of the transaction (the first entry's, for an income event).
  final int amount;

  /// One entry per item: several for an income recorded in one action.
  final List<CorrectionPreviewItem> items;
}

/// Delete, edit and reverse saved transactions, each in one step with the
/// balances (specs/20261008-010940-reverse-edit-transactions). Nothing here
/// knows about the database or the network; the person's own transactions only.
///
/// `now` is a required parameter of every action so the 24-hour window is
/// judged by the device clock at the moment the person acts (FR-002) and so it
/// can be tested.
abstract interface class TransactionCorrectionRepository {
  /// Deletes the transaction inside the correction window; an income entry is
  /// deleted together with every entry recorded in the same action (FR-005).
  Future<CorrectionResult> delete(
    String transactionId, {
    required DateTime now,
  });

  /// Changes an expense amount or destination without changing its recorded
  /// date (FR-004).
  Future<CorrectionResult> editExpense(
    String transactionId, {
    required int amount,
    required String itemId,
    required DateTime now,
  });

  /// Adds a linked transaction that cancels an old transaction; an income
  /// entry is reversed together with every entry recorded in the same action.
  Future<CorrectionResult> reverse(
    String transactionId, {
    required DateTime now,
  });

  /// The balances after [delete], for the confirmation. Writes nothing.
  Future<CorrectionPreview> previewDelete(String transactionId);

  /// The balances after [reverse], for the confirmation. Writes nothing.
  Future<CorrectionPreview> previewReverse(String transactionId);
}
