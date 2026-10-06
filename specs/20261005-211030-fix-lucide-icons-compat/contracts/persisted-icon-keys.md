# Contract: Persisted Icon Keys

**Feature**: `20261005-211030-fix-lucide-icons-compat` | **Date**: 2026-10-05

This is the only external-facing contract this feature touches. Icon keys are
stored in the local database and synced to/from Supabase, so existing rows on
any device — including rows pulled from other devices (#23) — must keep
resolving to the same icon after the icon package is replaced. **This feature
does not add, remove, or rename any key.**

## Key space (category icons)

Resolved by `resolveExpenseControlIcon(String key)` in
`lib/core/widgets/expense_control_icons.dart` and offered by the category icon
picker (`IconPicker`, which iterates `expenseControlIcons`).

| Persisted key | Icon constant | Canonical Lucide name today |
|---------------|---------------|-----------------------------|
| `home` | `LucideIcons.home` | `house` |
| `family` | `LucideIcons.users` | `users` |
| `wallet` | `LucideIcons.wallet` | `wallet` |
| `piggyBank` | `LucideIcons.piggyBank` | `piggy-bank` |
| `heart` | `LucideIcons.heartPulse` | `heart-pulse` |
| `utensils` | `LucideIcons.utensils` | `fork-knife` |
| `car` | `LucideIcons.car` | `car` |
| `shoppingBag` | `LucideIcons.shoppingBag` | `shopping-bag` |
| `gift` | `LucideIcons.gift` | `gift` |
| `graduationCap` | `LucideIcons.graduationCap` | `graduation-cap` |
| `receipt` | `LucideIcons.receipt` | `receipt` |
| `film` | `LucideIcons.film` | `film` |
| `building` | `LucideIcons.building2` | `building-complex` |
| `shield` | `LucideIcons.shield` | `shield` |
| `plane` | `LucideIcons.plane` | `plane` |
| `moreHorizontal` | `LucideIcons.moreHorizontal` | `ellipsis` |

**Fallback rule**: any key not in the table resolves to `LucideIcons.circle`
(never throws, never blank).

## Stored in

| Store | Field | Notes |
|-------|-------|-------|
| Drift `expense_control_items` | `iconKey` (non-null text) | key space above |
| Supabase `expense_control_items` | `icon_key` (`text not null`, `char_length > 0`) | same key space |
| Drift `financial_transactions` | `displayIconKey` (nullable text) | history snapshot |
| Supabase `financial_transactions` | `display_icon_key` (nullable text) | same |

## Secondary resolver (unchanged)

`_iconFor(String? key)` in `transaction_history_screen.dart` maps only `home`
→ `LucideIcons.home` and `utensils` → `LucideIcons.utensils`; any other key or
`null` → `LucideIcons.walletCards`. Behavior is preserved as-is (it is a
pre-existing divergence, noted in research.md and out of scope here).

## Compatibility guarantees for this feature

1. The key set above is unchanged (16 keys + fallback). A test pins it
   (research.md Decision 6.2).
2. Each key keeps resolving to the **same Lucide concept**; upstream
   stroke-level redraws are accepted (spec Clarifications).
3. No data migration, no rewrite of synced rows, no Supabase change.
4. The glyph for a key is looked up at render time only; nothing stores a
   codepoint or font family, so changing the font package cannot corrupt data.
