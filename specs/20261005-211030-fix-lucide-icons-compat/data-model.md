# Data Model: Restore Buildability — Fix Icon Library Incompatibility

**Feature**: `20261005-211030-fix-lucide-icons-compat` | **Date**: 2026-10-05

This feature changes **no stored data, no schema, and no domain entity**. The
"model" below is the inventory the spec's requirements are verified against,
the persisted identifiers that must keep resolving, and the one new code
artifact (the import seam).

## 1. Icon import seam (new)

| Attribute | Value |
|-----------|-------|
| File | `lib/core/theme/app_icons.dart` |
| Content | One re-export: `export 'package:lucide_flutter/lucide_flutter.dart' show LucideIcons;` |
| Consumers | All 28 files that referenced the old package today (18 in `lib/`, 10 in `test/`), via `import 'package:finance/core/theme/app_icons.dart';` |
| Invariant | It is the **only** file in `lib/` or `test/` that names the third-party icon package (enforced by the architecture test, research.md Decision 6.3). |
| Not included | No wrapper class, no per-icon getters, no runtime logic. |

## 2. Persisted icon identifiers (unchanged, must keep resolving — FR-005)

Stored as plain text; independent of the icon package's naming.

| Where stored | Column / field | Nullable | Resolved by |
|--------------|----------------|----------|-------------|
| Local (Drift) `expense_control_items` | `iconKey` | no | `resolveExpenseControlIcon` |
| Remote (Supabase) `expense_control_items` | `icon_key` (`text not null`, non-empty check) | no | same, after pull (#23) |
| Local `financial_transactions` | `displayIconKey` | yes | `_iconFor` in `transaction_history_screen.dart` |
| Remote `financial_transactions` | `display_icon_key` | yes | same |

The full key → icon table and the fallback rules are in
[contracts/persisted-icon-keys.md](./contracts/persisted-icon-keys.md).

## 3. Icon usage inventory (verification checklist for FR-004 / SC-004)

52 distinct `LucideIcons.*` constants referenced from `lib/` (18 files); the 10
test files reference 9 of them. Constants keep their current names (aliases
resolve to the same codepoint — research.md Decision 4), so **no call site is
renamed**.

| Constant | `lib/` files | `test/` files | Where (first files) |
|----------|-------------:|--------------:|---------------------|
| `alertTriangle` | 2 | 0 | overview_screen, report_screen |
| `arrowDownCircle` | 2 | 0 | expense_screen, spending_screen |
| `arrowUpCircle` | 2 | 0 | income_screen, spending_screen |
| `banknote` | 1 | 0 | overview_screen |
| `bell` | 4 | 1 | account_routes, account_screen, expenses_routes … |
| `briefcase` | 1 | 0 | income_screen |
| `building2` | 1 | 0 | expense_control_icons |
| `camera` | 1 | 0 | expense_screen |
| `car` | 1 | 0 | expense_control_icons |
| `check` | 5 | 0 | account_screen, sign_up_screen, expense_control_screen … |
| `checkCircle2` | 1 | 0 | expense_screen |
| `chevronDown` | 2 | 1 | expense_group_card, balance_group_card |
| `chevronLeft` | 5 | 2 | sign_up_screen, expense_screen, income_screen … |
| `chevronRight` | 6 | 1 | account_screen, expense_group_card, report_screen … |
| `circle` | 1 | 0 | expense_control_icons (fallback) |
| `cornerDownRight` | 1 | 0 | expense_screen |
| `delete` | 1 | 0 | expense_screen |
| `eye` | 2 | 0 | sign_in_screen, sign_up_screen |
| `eyeOff` | 2 | 0 | sign_in_screen, sign_up_screen |
| `film` | 1 | 0 | expense_control_icons |
| `fingerprint` | 1 | 0 | sign_in_screen |
| `gift` | 1 | 0 | expense_control_icons |
| `graduationCap` | 1 | 0 | expense_control_icons |
| `gripVertical` | 1 | 0 | expense_group_card |
| `heartPulse` | 1 | 0 | expense_control_icons |
| `helpCircle` | 2 | 0 | account_routes, account_screen |
| `history` | 3 | 2 | overview_screen, spending_screen, transaction_history_screen |
| `home` | 2 | 0 | expense_control_icons, transaction_history_screen |
| `info` | 1 | 0 | expense_control_screen |
| `languages` | 1 | 0 | account_screen |
| `layoutDashboard` | 2 | 1 | app_router, overview_screen |
| `logOut` | 1 | 0 | account_screen |
| `moreHorizontal` | 1 | 0 | expense_control_icons |
| `pencil` | 3 | 2 | expense_group_card, expense_item_row, expense_screen |
| `pieChart` | 3 | 1 | app_router, allocation_summary_banner, report_screen |
| `piggyBank` | 1 | 0 | expense_control_icons |
| `plane` | 1 | 0 | expense_control_icons |
| `plus` | 3 | 0 | expense_control_screen, expense_group_card, income_screen |
| `receipt` | 3 | 0 | app_router, expense_control_icons, overview_screen |
| `scanLine` | 1 | 0 | expense_screen |
| `shield` | 1 | 0 | expense_control_icons |
| `shieldCheck` | 2 | 0 | account_routes, account_screen |
| `shoppingBag` | 1 | 0 | expense_control_icons |
| `slidersHorizontal` | 2 | 0 | app_router, expense_control_screen |
| `sunMoon` | 1 | 0 | account_screen |
| `trash2` | 3 | 4 | expense_group_card, expense_item_row, income_screen |
| `user` | 2 | 0 | app_router, account_screen |
| `userPlus` | 1 | 0 | sign_up_screen |
| `users` | 1 | 0 | expense_control_icons |
| `utensils` | 2 | 0 | expense_control_icons, transaction_history_screen |
| `wallet` | 2 | 0 | expense_control_icons, overview_screen |
| `walletCards` | 4 | 0 | expense_screen, income_screen, spending_screen … |

Validation rules carried from the spec: every row must still compile (a
removed upstream constant is a compile error, never a silent change), render as
the same Lucide concept in light and dark appearance, keep its accessible
label/tooltip, and keep a ≥48×48dp touch target where it is the sole content of
a control.

## State transitions

None. No lifecycle or state is introduced or altered.
