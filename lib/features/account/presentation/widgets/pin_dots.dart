import 'package:flutter/material.dart';

import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_semantic_colors.dart';

/// The six dots that show how many digits of a PIN were typed, never which
/// (FR-012). A screen reader hears one sentence, "3 of 6 digits entered",
/// instead of six unlabeled shapes. Draws no text, so a digit cannot show.
class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.entered, this.total = 6});

  /// How many digits were typed so far.
  final int entered;

  /// How many digits a PIN has.
  final int total;

  static const double _size = 14;
  static const double _gap = 14;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    return Semantics(
      label: l10n.pinDotsSemantic(entered, total),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: _gap),
            Container(
              key: ValueKey('pin-dot-$i'),
              width: _size,
              height: _size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < entered ? theme.colorScheme.primary : null,
                border: Border.all(
                  color: i < entered
                      ? theme.colorScheme.primary
                      : semantic.border2,
                  width: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
