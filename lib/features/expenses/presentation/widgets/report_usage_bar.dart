import 'package:flutter/material.dart';

import 'package:finance/core/theme/app_semantic_colors.dart';

/// FR-013, research.md Decision 7: fill width is capped at 100% of the
/// track even when [usagePercent] exceeds it — the caller is responsible
/// for showing the true, uncapped number as text alongside this bar.
class ReportUsageBar extends StatelessWidget {
  const ReportUsageBar({super.key, required this.usagePercent});

  final double usagePercent;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final fillFraction = (usagePercent / 100).clamp(0.0, 1.0);
    final fillColor = usagePercent > 100
        ? semantic.dangerFg
        : Theme.of(context).colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: semantic.border1,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Container(
              height: 8,
              width: constraints.maxWidth * fillFraction,
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        );
      },
    );
  }
}
