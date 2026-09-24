import 'package:flutter/material.dart';

import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_semantic_colors.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';

/// Compact %/₫ pill toggle (mockup: pill bg, active chip blue-500/white,
/// inactive transparent/fg2). Extracted out of the item list (which now
/// conveys the mode via a suffix on its static label, FR-002, instead of
/// this interactive control — see expense_item_row.dart) so the item-edit
/// dialog (FR-013) can still reuse the exact same interactive control it
/// always used, without duplicating it.
class AllocationModeToggle extends StatelessWidget {
  const AllocationModeToggle({
    super.key,
    required this.method,
    required this.onChanged,
  });

  final ExpenseAllocationMethod method;
  final ValueChanged<ExpenseAllocationMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border.all(color: semantic.border1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _chip(
            context,
            label: '%',
            semanticLabel: l10n.expenseControlModePercentage,
            selected: method == ExpenseAllocationMethod.percentage,
            onTap: () => onChanged(ExpenseAllocationMethod.percentage),
          ),
          const SizedBox(width: 2),
          _chip(
            context,
            label: '₫',
            semanticLabel: l10n.expenseControlModeFixed,
            selected: method == ExpenseAllocationMethod.fixed,
            onTap: () => onChanged(ExpenseAllocationMethod.fixed),
          ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required String semanticLabel,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    // 32px tall per the design reference — the user explicitly chose to
    // match the design pixel-for-pixel here over Constitution Principle
    // III's ≥48dp touch target minimum for this control.
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 32,
          constraints: const BoxConstraints(minWidth: 40),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: selected ? theme.colorScheme.onPrimary : semantic.fg2,
            ),
          ),
        ),
      ),
    );
  }
}
