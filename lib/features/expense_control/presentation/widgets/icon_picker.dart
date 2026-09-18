import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/l10n/app_localizations.dart';

/// Curated, fixed icon set for Expense Control items/groups (research.md
/// §2) — the single string key (map key) is what's persisted, never the
/// [IconData] itself, so it stays stable across `lucide_icons` upgrades.
/// Display names double as the icon's Semantics label content (research.md
/// §11) and are intentionally kept as simple English identifiers, similar
/// to how icon/brand names are commonly left untranslated.
const Map<String, IconData> expenseControlIcons = {
  'home': LucideIcons.home,
  'family': LucideIcons.users,
  'wallet': LucideIcons.wallet,
  'piggyBank': LucideIcons.piggyBank,
  'heart': LucideIcons.heartPulse,
  'utensils': LucideIcons.utensils,
  'car': LucideIcons.car,
  'shoppingBag': LucideIcons.shoppingBag,
  'gift': LucideIcons.gift,
  'graduationCap': LucideIcons.graduationCap,
  'receipt': LucideIcons.receipt,
  'film': LucideIcons.film,
  'building': LucideIcons.building2,
  'shield': LucideIcons.shield,
  'plane': LucideIcons.plane,
  'moreHorizontal': LucideIcons.moreHorizontal,
};

/// Returns the [IconData] for a stored icon key, falling back to a generic
/// icon if the key is unrecognized (e.g. from a future icon set version).
IconData resolveExpenseControlIcon(String key) {
  return expenseControlIcons[key] ?? LucideIcons.circle;
}

class IconPicker extends StatelessWidget {
  const IconPicker({super.key, required this.selectedKey, required this.onSelected});

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
