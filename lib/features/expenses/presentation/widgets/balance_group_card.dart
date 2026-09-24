import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:finance/core/formatting/currency_formatter.dart';
import 'package:finance/core/theme/app_semantic_colors.dart';
import 'package:finance/core/widgets/dashed_border.dart';
import 'package:finance/core/widgets/expense_control_icons.dart';
import 'package:finance/features/expense_control/domain/expense_control_plan_service.dart';
import 'balance_item_row.dart';

/// One top-level card on "Thu chi" — a leaf (its own balance) or a group
/// (expandable children list, live-summed balance). Read-only throughout:
/// no edit/delete/add-child affordance anywhere (FR-005). Deliberately NOT
/// built on `ExpenseControlItem`'s own `ExpenseGroupCard` — that widget's
/// constructor requires edit/delete/add-child callbacks with no way to
/// suppress their rendered affordances (research.md). Only the visual
/// layout (icon badge, chevron, dashed child separators) is borrowed here,
/// reimplemented against this screen's own read-only contract.
class BalanceGroupCard extends StatefulWidget {
  const BalanceGroupCard({
    super.key,
    required this.node,
    required this.balance,
    required this.currency,
  });

  final ExpenseControlNode node;

  /// The node's displayed balance — its own stored value for a leaf, or the
  /// live sum of its children for a group (FR-001, computed by the caller
  /// via `ExpenseControlPlanService.computeItemBalance`).
  final int balance;

  final CurrencyFormatter currency;

  @override
  State<BalanceGroupCard> createState() => _BalanceGroupCardState();
}

class _BalanceGroupCardState extends State<BalanceGroupCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final item = widget.node.item;
    final isGroup = widget.node.isGroup;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: semantic.primarySoft,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    resolveExpenseControlIcon(item.iconKey),
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                BalanceAmountText(
                  amount: widget.balance,
                  currency: widget.currency,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (isGroup) ...[
                  const SizedBox(width: 6),
                  Icon(
                    _expanded
                        ? LucideIcons.chevronDown
                        : LucideIcons.chevronRight,
                    size: 16,
                    color: semantic.fg3,
                  ),
                ],
              ],
            ),
          ),
          if (isGroup && _expanded) ...[
            const SizedBox(height: 12),
            for (final child in widget.node.children)
              DashedTopBorder(
                color: semantic.border1,
                child: BalanceItemRow(item: child, currency: widget.currency),
              ),
          ],
        ],
      ),
    );
  }
}
