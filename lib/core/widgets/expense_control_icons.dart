import 'package:flutter/widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Stable presentation mapping for persisted expense-control icon keys.
///
/// The string key is persisted; IconData is resolved only when rendering.
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

/// Resolves a persisted icon key with a stable fallback for unknown values.
IconData resolveExpenseControlIcon(String key) {
  return expenseControlIcons[key] ?? LucideIcons.circle;
}
