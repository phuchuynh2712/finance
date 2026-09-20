import 'package:flutter/widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Curated, fixed icon set for Expense Control items/groups (research.md
/// §2) — the single string key (map key) is what's persisted, never the
/// [IconData] itself, so it stays stable across `lucide_icons` upgrades.
/// Lives in `domain/` (not `expense_control/presentation/`) because it
/// resolves a value intrinsic to `ExpenseControlItem.iconKey` itself, and
/// "Thu chi" (a different feature) needs the same resolution to render the
/// same items' icons without importing another feature's presentation
/// internals (Constitution Recommended Architecture).
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
