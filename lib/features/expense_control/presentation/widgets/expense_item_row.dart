import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/formatting/percent_formatter.dart';
import 'package:finance/core/theme/app_semantic_colors.dart';
import 'package:finance/core/widgets/expense_control_icons.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/presentation/formatting.dart';

/// One leaf item's row: icon/name/edit/delete header, plus its formula
/// shown as a non-interactive static label (FR-001/FR-002 — editing moved
/// entirely to the item's edit dialog; this widget has no input of its own
/// and no `onValueChanged`-style callback). Used both for child rows inside
/// a group and for a top-level leaf's own formula row.
class ExpenseItemRow extends StatelessWidget {
  const ExpenseItemRow({
    super.key,
    required this.item,
    this.showHeader = true,
    this.onEdit,
    this.onDelete,
  });

  final ExpenseControlItem item;

  /// False when the caller (e.g. [ExpenseGroupCard] for a top-level leaf)
  /// already renders its own icon/name/edit/delete header — this widget
  /// then renders only the formula label.
  final bool showHeader;

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;

    if (!showHeader) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: _FormulaLabel(item: item),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  resolveExpenseControlIcon(item.iconKey),
                  size: 11,
                  color: semantic.fg2,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.name,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onEdit != null)
                Semantics(
                  button: true,
                  label: l10n.expenseControlEditSemantic(item.name),
                  child: IconButton(
                    onPressed: onEdit,
                    icon: Icon(
                      LucideIcons.pencil,
                      size: 14,
                      color: semantic.fg3,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                  ),
                ),
              if (onDelete != null)
                Semantics(
                  button: true,
                  label: l10n.expenseControlDeleteSemantic(item.name),
                  child: IconButton(
                    onPressed: onDelete,
                    icon: Icon(
                      LucideIcons.trash2,
                      size: 15,
                      color: semantic.fg3,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 30, top: 8),
            child: _FormulaLabel(item: item),
          ),
        ],
      ),
    );
  }
}

/// FR-001/FR-002: a non-interactive display of the item's allocation
/// mode/value — sized to its content (no fixed width) so both a short
/// percentage ("24%") and a long fixed amount ("4.000.000 ₫") stay fully
/// visible, matching the design mockup's own side-by-side examples of both.
/// Tapping it does nothing; the only way to change the value is the item's
/// edit dialog (FR-003/FR-004).
class _FormulaLabel extends StatelessWidget {
  const _FormulaLabel({required this.item});

  final ExpenseControlItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final method = item.allocationMethod;
    final value = item.allocationValue;

    final text = switch ((method, value)) {
      (ExpenseAllocationMethod.percentage, final v?) => '${formatPercent(v)}%',
      (ExpenseAllocationMethod.fixed, final v?) => formatFixedAmount(
        context,
        v,
      ),
      _ => '',
    };

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border.all(color: semantic.border2, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: theme.textTheme.titleSmall),
    );
  }
}
