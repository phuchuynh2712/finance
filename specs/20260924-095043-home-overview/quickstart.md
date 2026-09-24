# Quickstart: Home Overview Verification

## Prerequisites

- Run from the repository root with Flutter dependencies available.
- Use a signed-in test user with at least two accounts (one top-level group
  with children, one plain leaf), and at least one recorded income and one
  recorded expense transaction.

## Verification Flow

1. Sign in and land on the "Tổng quan" tab (default/first tab). Confirm the
   placeholder screen is gone and a real, scrollable dashboard renders.
2. Confirm the header greets the user by their display name; sign in with an
   account that has no display name set and confirm it falls back to the
   email-prefix convention already used on Hồ sơ.
3. Confirm the total balance card shows both a compact figure (e.g. "12,4
   triệu ₫") and the exact full amount underneath, and that the compact
   figure's magnitude matches the sum of every account's balance shown further
   down the screen.
4. Drive one account's balance negative (e.g. record an expense larger than
   its balance, if the app allows it, or seed data directly). Confirm the
   warning banner appears, names that account, and "Xem chi tiết →" opens the
   Lịch sử giao dịch screen pre-filtered to that account's group (not the Kế
   hoạch tab). Bring the balance back to non-negative and confirm the banner
   disappears.
5. Confirm the accounts section lists every top-level account with its name
   and current balance, scrolls horizontally, and its "Xem tất cả" link
   navigates to the Kế hoạch tab (formerly labeled "Kiểm soát" — confirm the
   renamed bottom-nav label too, per FR-015).
6. Confirm the recent-transactions section shows the most recent transactions
   (newest first) across all accounts — not scoped to any single account or
   the current calendar month — each with description, account/group,
   relative time ("Hôm nay"/"Hôm qua"/"N ngày trước"), and a signed, colored
   amount. Confirm its "Xem tất cả" link opens the existing Lịch sử giao dịch
   screen.
7. Record a brand-new transaction and confirm it appears at the top of the
   Overview recent-transactions list without a manual refresh (FR-014).
8. Start with a fresh user (no accounts, no transactions). Confirm the
   accounts section and the recent-transactions section each show a distinct
   empty-state message instead of a blank area, while the total balance card
   still renders (as "0 ₫").
9. Tap the notification bell. Confirm it opens a separate "chưa khả dụng"
   screen, matching the Hồ sơ tab's notification row behavior exactly.
10. Force a data-load failure for one section (e.g. temporarily break a
    provider override in a debug build) and confirm only that section shows
    a retryable error state while the other sections continue to render
    normally; confirm retry recovers that section without affecting the
    others.
11. Verify Vietnamese and English labels, light/dark modes, screen-reader
    labels, the notification button's ≥48dp tap target, and locale-aware
    currency/date formatting throughout.

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

- `OverviewSummaryService`: total-balance fold, negative-account detection,
  and agreement with `BalanceViewService`'s per-account balances (same
  underlying `computeItemBalance` rule).
- `TransactionHistoryRepository.watchRecent(limit)`: returns at most `limit`
  rows, newest-first, excludes soft-deleted rows, is not bounded by any
  calendar month.
- `overview_recent_transactions.dart`'s relative-day bucketing (today /
  yesterday / N days ago) against an injected reference date — no
  `DateTime.now()` inside the pure function.
- `CurrencyFormatter.formatCompact`: the ≥1,000,000 vs. below-threshold
  branch, and the `vi` "X,Y triệu ₫" rendering.
- Negative-balance banner navigation: pushing `TransactionHistoryScreen`
  wrapped in a `ProviderScope` override seeds `selectedTransactionHistoryFilterProvider`
  to `TransactionHistoryFilter.group(accountName)`, and the pushed screen
  renders only that group's rows (existing `test/widget/features/expenses/transaction_history_screen_test.dart`'s
  `_HistoryRepository` fake needs no change; only the Overview-side push
  needs a widget test asserting the correct override was applied).
- Bottom-nav label: `tabExpenseControl` renders "Kế hoạch" (`vi`) / "Plan"
  (`en`) — update any existing widget test asserting the old "Kiểm soát" /
  "Control" text.
- Widget coverage for all four {has accounts / no accounts} × {has
  transactions / no transactions} combinations (SC-004), plus independent
  loading/error/retry per section (no cross-section blocking).
- Integration coverage: recording an income or expense transaction is
  reflected in Overview's total balance and recent-transactions list without
  a manual refresh.
