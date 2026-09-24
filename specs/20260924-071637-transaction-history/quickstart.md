# Quickstart: Transaction History Verification

## Prerequisites

- Run from the repository root with Flutter dependencies available.
- Use a signed-in test user with at least two expense-control items, including
  one grouped item and one income receiver.

## Verification Flow

1. Upgrade an existing local database containing financial transactions;
   confirm each legacy row gains immutable display data from its current source
   or the Archived Item fallback without changing amounts/directions; confirm
   `updated_at` is populated and `deleted_at` is null.
2. Record an income allocation across two recipient items. Confirm two income
   rows are created with recipient-item names, Income classification, matching
   positive amounts, shared occurrence time, snapshots, and outbox payloads.
3. Record an expense. Confirm it creates one expense row with the selected
   item's captured name/group/icon and an outbox payload in the same atomic
   transaction as the balance change.
4. Rename and then soft-delete source items. Confirm prior history retains its
   original snapshot and selected-month filters include matching deleted-group
   history.
5. Open transaction history from Spending. Confirm no bottom navigation is
   shown, current month is selected, expense total excludes income, rows are
   newest-first and grouped by local date.
6. Move to a prior month, return to current month, and confirm future-month
   navigation is unavailable.
7. Select All, each displayed group, and Income. Confirm one active filter,
   correct rows, and retained selection in empty/error/retry states.
8. Verify Vietnamese and English labels, light/dark modes, screen-reader
   labels, 48dp controls, long labels, and locale-aware dates/VND amounts.
9. Seed 100 selected-month transactions, apply every filter, and verify each
   filtered result becomes available within 1 second under normal conditions.

## Automated Checks

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test test/unit/features/expense_control
flutter test test/unit/features/expenses
flutter test test/widget/features/expenses
flutter test test/integration
flutter test
```

## Required Regression Coverage

- Cumulative database migration from the last released schema version;
  backfill and Archived Item fallback.
- Transaction insert and outbox payload snapshots for income and expense.
- Selected-month boundaries, ordering, totals, filters, and date grouping.
- A 100-row filter performance measurement against SC-003.
- Spending-to-history navigation, month controls, loading/empty/error/retry,
  localization, and light/dark rendering.