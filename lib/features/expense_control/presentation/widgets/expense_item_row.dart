import 'package:flutter/material.dart';

import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/formatting/percent_formatter.dart';
import 'package:finance/core/theme/app_icons.dart';
import 'package:finance/core/theme/app_layout.dart';
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

    final inline = useInlineFormulaLabel(context);

    if (!showHeader) {
      // On a wide window the owning card's header already shows the box
      // beside the name, so there is nothing to render here.
      if (inline) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: ExpenseFormulaLabel(item: item),
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
              if (inline) ...[
                const SizedBox(width: 8),
                ExpenseFormulaLabel(item: item, bounded: true),
              ],
              if (onEdit != null)
                Semantics(
                  button: true,
                  label: l10n.expenseControlEditSemantic(item.name),
                  child: IconButton(
                    onPressed: onEdit,
                    tooltip: l10n.expenseControlEditSemantic(item.name),
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
                    tooltip: l10n.expenseControlDeleteSemantic(item.name),
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
          if (!inline)
            Padding(
              padding: const EdgeInsets.only(left: 30, top: 8),
              child: ExpenseFormulaLabel(item: item),
            ),
        ],
      ),
    );
  }
}

/// Whether the window is wide enough (≥ 600dp, [WindowSizeClass.medium]) for
/// the allocation box to sit next to the item's name instead of below it.
bool useInlineFormulaLabel(BuildContext context) =>
    windowSizeClassFor(MediaQuery.sizeOf(context).width).index >=
    WindowSizeClass.medium.index;

/// FR-001/FR-002: a non-interactive display of the item's allocation
/// mode/value. Tapping it does nothing; the only way to change the value is
/// the item's edit dialog (FR-003/FR-004).
///
/// Below 600dp it spans the row beneath the item's name, exactly as before.
/// On a wide window ([bounded]) it sits beside the name and is sized to its
/// text, between 96 and 200dp, so a short percentage ("24%") and a long fixed
/// amount ("4.000.000 ₫") both stay fully visible without the box stretching
/// across a 900dp row like an input (specs/20261007-100751-adaptive-web-
/// remaining-screens/research.md, Decision 9).
class ExpenseFormulaLabel extends StatelessWidget {
  const ExpenseFormulaLabel({
    super.key,
    required this.item,
    this.bounded = false,
  });

  final ExpenseControlItem item;
  final bool bounded;

  static const double minWidth = 96;
  static const double maxWidth = 200;

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
    final decoration = BoxDecoration(
      border: Border.all(color: semantic.border2, width: 1.5),
      borderRadius: BorderRadius.circular(4),
    );

    if (bounded) {
      return Container(
        height: 40,
        constraints: const BoxConstraints(
          minWidth: minWidth,
          maxWidth: maxWidth,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: decoration,
        child: Center(
          widthFactor: 1,
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
        ),
      );
    }
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.centerLeft,
      decoration: decoration,
      child: Text(text, style: theme.textTheme.titleSmall),
    );
  }
}
