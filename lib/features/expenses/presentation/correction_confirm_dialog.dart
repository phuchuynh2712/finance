import 'package:flutter/material.dart';

import 'package:finance/core/formatting/currency_formatter.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_semantic_colors.dart';
import 'package:finance/features/expense_control/domain/transaction_correction_repository.dart';

/// Shared confirmation for destructive transaction corrections.
class CorrectionConfirmDialog extends StatefulWidget {
  const CorrectionConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.preview,
    required this.onConfirm,
    required this.icon,
    this.detailsNote,
    super.key,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final CorrectionPreview preview;
  final Future<CorrectionResult> Function() onConfirm;
  final IconData icon;
  final String? detailsNote;

  @override
  State<CorrectionConfirmDialog> createState() =>
      _CorrectionConfirmDialogState();
}

class _CorrectionConfirmDialogState extends State<CorrectionConfirmDialog> {
  bool _isSaving = false;

  Future<void> _confirm() async {
    setState(() => _isSaving = true);
    try {
      final result = await widget.onConfirm();
      if (mounted) Navigator.of(context).pop(result);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currency = CurrencyFormatter(
      Localizations.localeOf(context).toString(),
    );
    final negativeBalance = widget.preview.items.any(
      (item) => !item.itemRemoved && item.balanceAfter < 0,
    );
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;

    return AlertDialog(
      title: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                widget.icon,
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title,
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
            Text(widget.message, style: theme.textTheme.bodyLarge),
            if (widget.detailsNote case final note?) ...[
              const SizedBox(height: 8),
              Text(
                note,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (widget.preview.items.isNotEmpty) ...[
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
                        l10n.correctionResultingBalancesLabel,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (
                        var index = 0;
                        index < widget.preview.items.length;
                        index++
                      ) ...[
                        if (index > 0) const Divider(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              widget.preview.items[index].itemRemoved
                                  ? Icons.info_outline_rounded
                                  : Icons.account_balance_wallet_outlined,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.preview.items[index].itemRemoved
                                    ? l10n.correctionItemRemovedNote
                                    : l10n.correctionBalanceLine(
                                        widget.preview.items[index].itemName,
                                        currency.format(
                                          widget
                                              .preview
                                              .items[index]
                                              .balanceAfter,
                                        ),
                                      ),
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            if (negativeBalance) ...[
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
        OverflowBar(
          alignment: MainAxisAlignment.end,
          spacing: 8,
          overflowSpacing: 8,
          children: [
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
            FilledButton.icon(
              onPressed: _isSaving ? null : _confirm,
              icon: Icon(widget.icon, size: 18),
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              label: Text(widget.confirmLabel),
            ),
          ],
        ),
      ],
    );
  }
}
