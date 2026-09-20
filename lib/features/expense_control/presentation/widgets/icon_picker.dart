import 'package:flutter/material.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../domain/expense_control_icons.dart';

class IconPicker extends StatelessWidget {
  const IconPicker({
    super.key,
    required this.selectedKey,
    required this.onSelected,
  });

  final String? selectedKey;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in expenseControlIcons.entries)
          Semantics(
            button: true,
            selected: entry.key == selectedKey,
            label: l10n.expenseControlIconSemanticLabel(entry.key),
            child: InkWell(
              onTap: () => onSelected(entry.key),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: entry.key == selectedKey
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                ),
                child: Icon(
                  entry.value,
                  color: entry.key == selectedKey
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
