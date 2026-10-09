import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance/core/di/expense_dependencies.dart';
import 'package:finance/core/formatting/currency_formatter.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_semantic_colors.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/domain/transaction_history_record.dart';

class EditBalancePreview {
  const EditBalancePreview({
    required this.item,
    required this.balanceBefore,
    required this.balanceAfter,
  });

  final ExpenseControlItem item;
  final int balanceBefore;
  final int balanceAfter;
}

/// Pure balance preview for changing an expense's amount or destination.
List<EditBalancePreview> buildEditBalancePreview({
  required TransactionHistoryRecord record,
  required int amount,
  required String itemId,
  required List<ExpenseControlItem> items,
}) {
  final oldItem = items
      .where((item) => item.id == record.sourceItemId)
      .firstOrNull;
  final newItem = items.where((item) => item.id == itemId).firstOrNull;
  if (newItem == null) return const [];

  if (oldItem?.id == newItem.id) {
    return [
      EditBalancePreview(
        item: newItem,
        balanceBefore: newItem.balance,
        balanceAfter: newItem.balance + record.amount - amount,
      ),
    ];
  }

  return [
    if (oldItem != null)
      EditBalancePreview(
        item: oldItem,
        balanceBefore: oldItem.balance,
        balanceAfter: oldItem.balance + record.amount,
      ),
    EditBalancePreview(
      item: newItem,
      balanceBefore: newItem.balance,
      balanceAfter: newItem.balance - amount,
    ),
  ];
}

/// Edits an expense while preserving its original occurred-at timestamp.
class EditExpenseDialog extends ConsumerStatefulWidget {
  const EditExpenseDialog({
    required this.record,
    required this.items,
    super.key,
  });

  final TransactionHistoryRecord record;
  final List<ExpenseControlItem> items;

  @override
  ConsumerState<EditExpenseDialog> createState() => _EditExpenseDialogState();
}

class _EditExpenseDialogState extends ConsumerState<EditExpenseDialog> {
  late final TextEditingController _amountController;
  late final List<ExpenseControlItem> _leafItems;
  String? _selectedItemId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.record.amount.toString(),
    );
    final parentIds = widget.items.map((item) => item.parentId).toSet();
    _leafItems = [
      for (final item in widget.items)
        if (item.allocationMethod != null && !parentIds.contains(item.id)) item,
    ];
    _selectedItemId =
        _leafItems
            .where((item) => item.id == widget.record.sourceItemId)
            .firstOrNull
            ?.id ??
        _leafItems.firstOrNull?.id;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = int.tryParse(_amountController.text);
    final itemId = _selectedItemId;
    if (_isSaving || amount == null || amount <= 0 || itemId == null) return;

    setState(() => _isSaving = true);
    try {
      final result = await ref
          .read(transactionCorrectionRepositoryProvider)
          .editExpense(
            widget.record.id,
            amount: amount,
            itemId: itemId,
            now: ref.read(correctionNowProvider)(),
          );
      if (mounted) Navigator.of(context).pop(result);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final currency = CurrencyFormatter(
      Localizations.localeOf(context).toString(),
    );
    final amount = int.tryParse(_amountController.text) ?? 0;
    final selectedItemId = _selectedItemId;
    final preview = selectedItemId == null || amount <= 0
        ? const <EditBalancePreview>[]
        : buildEditBalancePreview(
            record: widget.record,
            amount: amount,
            itemId: selectedItemId,
            items: _leafItems,
          );
    final hasNegativeBalance = preview.any((item) => item.balanceAfter < 0);

    return AlertDialog(
      title: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                Icons.edit_outlined,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.correctionEditTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                labelText: l10n.correctionEditAmountLabel,
                prefixIcon: const Icon(Icons.payments_outlined),
                suffixText: '₫',
                errorText: _amountController.text.isEmpty || amount <= 0
                    ? l10n.correctionErrorAmount
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            if (_leafItems.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: selectedItemId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.correctionEditItemLabel,
                  prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                ),
                items: [
                  for (final item in _leafItems)
                    DropdownMenuItem(
                      value: item.id,
                      child: Text(item.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: _isSaving
                    ? null
                    : (value) => setState(() => _selectedItemId = value),
              ),
            if (_leafItems.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.correctionErrorItemRemoved,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            if (preview.isNotEmpty) ...[
              const SizedBox(height: 16),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.correctionEditBalanceTitle,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (var index = 0; index < preview.length; index++) ...[
                        if (index > 0) const Divider(height: 20),
                        _BalancePreviewRow(
                          line: preview[index],
                          currency: currency,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            if (hasNegativeBalance) ...[
              const SizedBox(height: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: semantic.warningSoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 20,
                        color: semantic.warningFg,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.correctionNegativeBalanceWarning,
                          style: TextStyle(
                            color: semantic.warningFg,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          autofocus: true,
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: Text(l10n.cancelAction),
        ),
        FilledButton(
          onPressed:
              _isSaving ||
                  amount <= 0 ||
                  selectedItemId == null ||
                  preview.isEmpty
              ? null
              : _save,
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: Text(l10n.correctionEditSave),
        ),
      ],
    );
  }
}

class _BalancePreviewRow extends StatelessWidget {
  const _BalancePreviewRow({required this.line, required this.currency});

  final EditBalancePreview line;
  final CurrencyFormatter currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          line.item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                currency.format(line.balanceBefore),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              currency.format(line.balanceAfter),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
