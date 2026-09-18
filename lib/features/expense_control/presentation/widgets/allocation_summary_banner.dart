import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../domain/expense_control_plan_service.dart';
import '../formatting.dart';

/// FR-011: running allocation summary — percent allocated, fixed-item
/// count, percent free. Renders from [ExpenseControlTotals] computed by
/// [ExpenseControlPlanService], including any pending formula edits
/// (research.md §9).
class AllocationSummaryBanner extends StatelessWidget {
  const AllocationSummaryBanner({super.key, required this.totals});

  final ExpenseControlTotals totals;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: semantic.warningSoft,
        border: Border.all(color: semantic.warning.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.pieChart, size: 16, color: semantic.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.allocationSummaryAllocatedLine(
                    formatPercent(totals.percentAllocated),
                    totals.fixedItemCount,
                  ),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: semantic.warningFg,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.allocationSummaryFreeLine(
                    formatPercent(totals.percentFree),
                  ),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: semantic.warningFg,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
