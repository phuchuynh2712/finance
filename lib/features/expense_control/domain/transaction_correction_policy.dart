import 'package:finance/features/expense_control/domain/transaction_history_record.dart';

/// An operation available for a saved transaction (FR-002, FR-005, FR-007).
enum CorrectionAction { delete, edit, reverse }

/// Applies the device-clock correction window and record-state rules.
///
/// The window is evaluated at the moment the person acts, and an edit never
/// changes the transaction's original `occurredAt` (FR-002).
abstract final class TransactionCorrectionPolicy {
  static const Duration window = Duration(hours: 24);

  /// Whether [occurredAt] is less than [window] before [now].
  ///
  /// A future [occurredAt] counts as inside the window, which also tolerates a
  /// device clock that is behind the time recorded on the transaction.
  static bool isInsideWindow(DateTime occurredAt, DateTime now) =>
      now.difference(occurredAt) < window;

  /// Returns the operations permitted for this history [record].
  static Set<CorrectionAction> availableActions(
    TransactionHistoryRecord record,
    DateTime now,
  ) {
    if (record.isReversal || record.isReversed) return const {};

    if (isInsideWindow(record.occurredAt, now)) {
      return switch (record.direction) {
        TransactionHistoryDirection.expense => const {
          CorrectionAction.delete,
          CorrectionAction.edit,
        },
        TransactionHistoryDirection.income => const {CorrectionAction.delete},
      };
    }

    return const {CorrectionAction.reverse};
  }
}
