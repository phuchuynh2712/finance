import 'package:flutter/material.dart';

import 'package:finance/core/formatting/currency_formatter.dart';
import 'package:finance/core/theme/app_semantic_colors.dart';
import 'package:finance/core/widgets/expense_control_icons.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';

/// One child row inside an expanded [BalanceGroupCard] (FR-001, FR-002).
/// Read-only — no edit/delete affordance, unlike Kiểm soát chi tiêu's
/// `ExpenseItemRow` (FR-005): this screen never mutates an item.
class BalanceItemRow extends StatelessWidget {
  const BalanceItemRow({super.key, required this.item, required this.currency});

  final ExpenseControlItem item;
  final CurrencyFormatter currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              resolveExpenseControlIcon(item.iconKey),
              size: 12,
              color: semantic.fg2,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.name,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          BalanceAmountText(
            amount: item.balance,
            currency: currency,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// A currency amount colored per FR-004: positive/zero in the app's
/// informational color, negative in the danger color with a visible minus
/// sign — [CurrencyFormatter] already renders the sign, this widget only
/// supplies the color.
class BalanceAmountText extends StatelessWidget {
  const BalanceAmountText({
    super.key,
    required this.amount,
    required this.currency,
    this.style,
  });

  final int amount;
  final CurrencyFormatter currency;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = amount < 0
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    return Text(
      currency.format(amount),
      textAlign: TextAlign.right,
      style: style?.copyWith(color: color) ?? TextStyle(color: color),
    );
  }
}
