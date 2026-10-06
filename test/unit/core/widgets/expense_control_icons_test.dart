import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/theme/app_icons.dart';
import 'package:finance/core/widgets/expense_control_icons.dart';

void main() {
  // The persisted contract: these keys are stored in the local database
  // (`iconKey`) and synced to Supabase (`icon_key`), so existing rows on any
  // device must keep resolving to the same icon. See
  // specs/20261005-211030-fix-lucide-icons-compat/contracts/persisted-icon-keys.md.
  const pinned = <String, IconData>{
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

  test('offers exactly the persisted icon keys', () {
    expect(expenseControlIcons.keys, unorderedEquals(pinned.keys));
  });

  test('every persisted key resolves to its pinned icon', () {
    for (final entry in pinned.entries) {
      expect(
        resolveExpenseControlIcon(entry.key),
        entry.value,
        reason: 'Key "${entry.key}" must keep resolving to the same icon.',
      );
    }
  });

  test('unknown and empty keys fall back to the circle icon', () {
    expect(resolveExpenseControlIcon('does-not-exist'), LucideIcons.circle);
    expect(resolveExpenseControlIcon(''), LucideIcons.circle);
  });
}
