import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:finance/core/di/expense_dependencies.dart';
import 'package:finance/core/formatting/currency_formatter.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_semantic_colors.dart';
import 'package:finance/features/expense_control/domain/transaction_correction_policy.dart';
import 'package:finance/features/expense_control/domain/transaction_correction_repository.dart';
import 'package:finance/features/expense_control/domain/transaction_history_record.dart';
import 'package:finance/features/expense_control/domain/transaction_history_repository.dart';
import 'package:finance/features/expenses/presentation/correction_confirm_dialog.dart';
import 'package:finance/features/expenses/presentation/edit_expense_dialog.dart';

/// Opens transaction details as a bottom sheet on phones and a bounded dialog
/// on larger windows.
Future<void> showTransactionActions(
  BuildContext context,
  TransactionHistoryRecord record,
) {
  final sheet = TransactionActionsSheet(record: record);
  if (MediaQuery.sizeOf(context).width >= 600) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: sheet,
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => sheet,
  );
}

class TransactionActionsSheet extends ConsumerStatefulWidget {
  const TransactionActionsSheet({required this.record, super.key});

  final TransactionHistoryRecord record;

  @override
  ConsumerState<TransactionActionsSheet> createState() =>
      _TransactionActionsSheetState();
}

class _TransactionActionsSheetState
    extends ConsumerState<TransactionActionsSheet> {
  bool _isWorking = false;

  Future<void> _delete() async {
    if (_isWorking) return;
    setState(() => _isWorking = true);
    try {
      final repository = ref.read(transactionCorrectionRepositoryProvider);
      final now = ref.read(correctionNowProvider)();
      final preview = await repository.previewDelete(widget.record.id);
      if (!mounted) return;

      final l10n = AppLocalizations.of(context);
      final locale = Localizations.localeOf(context).toString();
      final currency = CurrencyFormatter(locale);
      final firstItem = preview.items.firstOrNull;
      final itemName = firstItem?.itemName ?? widget.record.displayName;
      final amountSign =
          widget.record.direction == TransactionHistoryDirection.income
          ? '+'
          : '-';
      final result = await showDialog<CorrectionResult>(
        context: context,
        builder: (_) => CorrectionConfirmDialog(
          title: l10n.correctionDeleteTitle,
          message: l10n.correctionDeleteMessage(
            '$amountSign${currency.format(preview.amount)}',
            itemName,
          ),
          icon: Icons.delete_outline_rounded,
          detailsNote:
              widget.record.direction == TransactionHistoryDirection.income
              ? l10n.correctionIncomeEventNote(preview.items.length)
              : null,
          confirmLabel: l10n.correctionActionDelete,
          preview: preview,
          onConfirm: () => repository.delete(widget.record.id, now: now),
        ),
      );
      if (!mounted || result == null) return;
      _finish(result, successMessage: l10n.correctionDoneDeleted);
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _edit() async {
    if (_isWorking) return;
    setState(() => _isWorking = true);
    try {
      final items = await ref.read(expenseControlRepositoryProvider).getAll();
      if (!mounted) return;
      final result = await showDialog<CorrectionResult>(
        context: context,
        builder: (_) => EditExpenseDialog(record: widget.record, items: items),
      );
      if (!mounted || result == null) return;
      _finish(
        result,
        successMessage: AppLocalizations.of(context).correctionDoneEdited,
      );
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _reverse() async {
    if (_isWorking) return;
    setState(() => _isWorking = true);
    try {
      final repository = ref.read(transactionCorrectionRepositoryProvider);
      final now = ref.read(correctionNowProvider)();
      final preview = await repository.previewReverse(widget.record.id);
      if (!mounted) return;

      final l10n = AppLocalizations.of(context);
      final currency = CurrencyFormatter(
        Localizations.localeOf(context).toString(),
      );
      final firstItem = preview.items.firstOrNull;
      final itemName = firstItem?.itemName ?? widget.record.displayName;
      final result = await showDialog<CorrectionResult>(
        context: context,
        builder: (_) => CorrectionConfirmDialog(
          title: l10n.correctionReverseTitle,
          message: l10n.correctionReverseMessage(
            currency.format(preview.amount),
            itemName,
          ),
          icon: Icons.undo_rounded,
          detailsNote:
              widget.record.direction == TransactionHistoryDirection.income
              ? l10n.correctionIncomeEventNote(preview.items.length)
              : null,
          confirmLabel: l10n.correctionActionReverse,
          preview: preview,
          onConfirm: () => repository.reverse(widget.record.id, now: now),
        ),
      );
      if (!mounted || result == null) return;
      _finish(result, successMessage: l10n.correctionDoneReversed);
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _openRelatedTransaction(String? transactionId) async {
    if (transactionId == null) return;
    final repository = ref.read(expenseControlRepositoryProvider);
    if (repository is! TransactionHistoryLookup) {
      throw StateError(
        'Transaction history does not support transaction lookup.',
      );
    }
    final related = await (repository as TransactionHistoryLookup)
        .getTransactionById(transactionId);
    if (!mounted) return;
    if (related == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).correctionErrorNoLongerAvailable,
          ),
        ),
      );
      return;
    }
    await showTransactionActions(context, related);
  }

  void _finish(CorrectionResult result, {required String successMessage}) {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final message = switch (result) {
      CorrectionDone() => successMessage,
      CorrectionNotAllowed(:final denial) => switch (denial) {
        CorrectionDenial.windowEnded => l10n.correctionErrorWindowEnded,
        CorrectionDenial.windowStillOpen =>
          l10n.correctionErrorNoLongerAvailable,
        CorrectionDenial.invalidAmount => l10n.correctionErrorAmount,
        CorrectionDenial.itemRemoved => l10n.correctionErrorItemRemoved,
        _ => l10n.correctionErrorNoLongerAvailable,
      },
    };
    Navigator.of(context).pop();
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final record = widget.record;
    final isIncome = record.direction == TransactionHistoryDirection.income;
    final isPositive = record.isReversal ? !isIncome : isIncome;
    final amount = CurrencyFormatter(
      Localizations.localeOf(context).toString(),
    ).format(record.amount);
    final actions = TransactionCorrectionPolicy.availableActions(
      record,
      ref.read(correctionNowProvider)(),
    );
    final itemName = record.displayName.isEmpty
        ? l10n.transactionHistoryArchivedItem
        : record.displayName;
    final groupName = record.displayGroupName;
    final signedAmount = '${isPositive ? '+' : '-'}$amount';
    final stateLabel = record.isReversal
        ? l10n.historyTagReversal
        : record.isReversed
        ? l10n.historyTagReversed
        : null;
    final dateLabel = DateFormat(
      'd MMM y · HH:mm',
      Localizations.localeOf(context).toString(),
    ).format(record.occurredAt);

    return Semantics(
      label:
          '$signedAmount, $itemName, ${groupName ?? ''}, ${stateLabel ?? ''}',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    itemName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.cancelAction,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (groupName != null) Text(groupName),
            const SizedBox(height: 12),
            Text(
              signedAmount,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: isPositive
                    ? semantic.successFg
                    : theme.colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(dateLabel, style: theme.textTheme.bodyMedium),
            if (record.isReversed)
              TextButton(
                onPressed: _isWorking
                    ? null
                    : () => _openRelatedTransaction(record.reversedById),
                child: Text(l10n.correctionSheetReversedTag),
              ),
            if (record.isReversal)
              TextButton(
                onPressed: _isWorking
                    ? null
                    : () => _openRelatedTransaction(record.reversesId),
                child: Text(l10n.correctionSheetReversalOf(itemName)),
              ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 18),
              if (actions.contains(CorrectionAction.edit)) ...[
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _isWorking ? null : _edit,
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(l10n.correctionActionEdit),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (actions.contains(CorrectionAction.delete))
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _isWorking ? null : _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l10n.correctionActionDelete),
                  ),
                ),
              if (actions.contains(CorrectionAction.reverse))
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _isWorking ? null : _reverse,
                    icon: const Icon(Icons.undo),
                    label: Text(l10n.correctionActionReverse),
                  ),
                ),
            ],
            if (actions.isEmpty && stateLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(l10n.correctionSheetNoActionReversed),
              ),
          ],
        ),
      ),
    );
  }
}
