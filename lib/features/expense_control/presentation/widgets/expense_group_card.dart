import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/formatting/percent_formatter.dart';
import 'package:finance/core/theme/app_semantic_colors.dart';
import 'package:finance/core/widgets/dashed_border.dart';
import 'package:finance/core/widgets/expense_control_icons.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/domain/expense_control_plan_service.dart';
import 'expense_item_row.dart';

/// One top-level card — a leaf (its own formula row) or a group (children
/// list + "Thêm khoản trong [Tên nhóm]"). The header (grip/icon/name/
/// edit/delete/chevron) is shared by both shapes, matching the mockup.
class ExpenseGroupCard extends StatefulWidget {
  const ExpenseGroupCard({
    super.key,
    required this.node,
    required this.index,
    required this.onEditItem,
    required this.onDeleteLeaf,
    required this.onDeleteGroup,
    required this.onAddChild,
    this.groupSubtotal,
  });

  final ExpenseControlNode node;
  final int index;
  final void Function(ExpenseControlItem item) onEditItem;
  final void Function(ExpenseControlItem item) onDeleteLeaf;
  final void Function(ExpenseControlItem group) onDeleteGroup;
  final void Function(ExpenseControlItem group) onAddChild;

  /// A group carries no formula of its own (FR-003/FR-004); its effective
  /// value is the live sum of its children, computed by the caller and
  /// rendered as the sub-label under the group's name (FR-024). `null` for
  /// a leaf.
  final ExpenseControlTotals? groupSubtotal;

  @override
  State<ExpenseGroupCard> createState() => _ExpenseGroupCardState();
}

class _ExpenseGroupCardState extends State<ExpenseGroupCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final item = widget.node.item;
    final isGroup = widget.node.isGroup;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: semantic.border1),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: isGroup
                ? () => setState(() => _expanded = !_expanded)
                : null,
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: widget.index,
                  child: Semantics(
                    label: l10n.expenseControlReorderSemantic(item.name),
                    child: Icon(
                      LucideIcons.gripVertical,
                      size: 15,
                      color: semantic.fg3,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: semantic.primarySoft,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    resolveExpenseControlIcon(item.iconKey),
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      // FR-014: only shown while collapsed — while
                      // expanded, the children list below already shows
                      // this information, so the summary would duplicate
                      // it. FR-015: never truncated when it IS shown, so
                      // no `overflow` — it wraps naturally instead.
                      if (!_expanded)
                        if (widget.groupSubtotal case final subtotal?)
                          Text(
                            l10n.allocationSummaryAllocatedLine(
                              formatPercent(subtotal.percentAllocated),
                              subtotal.fixedItemCount,
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: semantic.fg2,
                            ),
                          ),
                    ],
                  ),
                ),
                Semantics(
                  button: true,
                  label: l10n.expenseControlEditSemantic(item.name),
                  child: IconButton(
                    onPressed: () => widget.onEditItem(item),
                    tooltip: l10n.expenseControlEditSemantic(item.name),
                    icon: Icon(
                      LucideIcons.pencil,
                      size: 15,
                      color: semantic.fg3,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  label: l10n.expenseControlDeleteSemantic(item.name),
                  child: IconButton(
                    onPressed: () => isGroup
                        ? widget.onDeleteGroup(item)
                        : widget.onDeleteLeaf(item),
                    tooltip: l10n.expenseControlDeleteSemantic(item.name),
                    icon: Icon(
                      LucideIcons.trash2,
                      size: 16,
                      color: semantic.fg3,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                  ),
                ),
                if (isGroup)
                  Semantics(
                    button: true,
                    label: _expanded
                        ? l10n.expenseControlCollapseSemantic(item.name)
                        : l10n.expenseControlExpandSemantic(item.name),
                    child: Icon(
                      _expanded
                          ? LucideIcons.chevronDown
                          : LucideIcons.chevronRight,
                      size: 15,
                      color: semantic.fg3,
                    ),
                  ),
              ],
            ),
          ),
          if (isGroup && _expanded) ...[
            const SizedBox(height: 10),
            for (final child in widget.node.children)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: DashedTopBorder(
                  color: semantic.border1,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: ExpenseItemRow(
                      item: child,
                      onEdit: () => widget.onEditItem(child),
                      onDelete: () => widget.onDeleteLeaf(child),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _AddChildButton(
                label: l10n.expenseControlAddChildAction(item.name),
                onPressed: () => widget.onAddChild(item),
              ),
            ),
          ] else if (!isGroup) ...[
            ExpenseItemRow(item: item, showHeader: false),
            // FR-002: a leaf becomes a group the moment it gets its first
            // child — this affordance must be available on every leaf, not
            // only after it's already a group (that would make the
            // leaf→group transition unreachable).
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _AddChildButton(
                label: l10n.expenseControlAddChildAction(item.name),
                onPressed: () => widget.onAddChild(item),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Thêm khoản trong [Tên nhóm]" — dashed border, matching the mockup
/// (a plain `OutlinedButton` only draws solid borders).
class _AddChildButton extends StatelessWidget {
  const _AddChildButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DashedRectBorder(
      color: theme.colorScheme.primary,
      borderRadius: 4,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.plus,
                  size: 13,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
