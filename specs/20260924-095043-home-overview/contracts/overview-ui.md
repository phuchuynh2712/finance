# Internal UI Contract: Home Overview Screen

## Purpose

Define the application-facing data and state contract used by the Overview
("Tổng quan") tab. This is an internal Flutter application contract, not a
public HTTP API. Overview is read-only — it exposes no write/command contract
of its own (FR-013); all mutation stays owned by the Kế hoạch and Thu chi
tabs' existing contracts.

## Gateway Contracts

Overview composes two existing domain contracts, each already owned by
`expense_control` and unchanged in shape by this feature except one additive
method:

- **`ExpenseControlPlanService.computeItemBalance(ExpenseControlNode)`**
  (existing, unchanged) — the per-root loop that produces `OverviewSummary`.
- **`TransactionHistoryRepository`** (existing interface, one method added):
  `Stream<List<TransactionHistoryRecord>> watchRecent({required int limit})`
  — returns the `limit` most recent, non-deleted records for the current
  user across all accounts, sorted by occurrence time descending, independent
  of any calendar-month boundary. Existing `watchTransactionHistory(start,
  end)` is unchanged and still owns the month-scoped read used by the full
  Lịch sử giao dịch screen.

Neither contract exposes Drift, Supabase, or widget types to the presentation
layer — `OverviewSummaryService` and `overview_recent_transactions.dart`'s
pure mapping function are the only things `overview_screen.dart` depends on.

## Presentation Inputs

| Input | Behavior |
|---|---|
| Signed-in user's display name | From `authRepositoryProvider.currentDisplayName`, falling back to the email-prefix convention when absent (FR-008). |
| Account tree | From the existing `expenseControlTreeProvider`; drives both `OverviewSummary` and the accounts list — a single source, so the total and the per-account cards can never disagree. |
| Recent transactions | From `TransactionHistoryRepository.watchRecent(limit: 5)` (FR-006, spec.md Assumptions). |
| Locale | `Localizations.localeOf(context)`, used for `CurrencyFormatter`/`CurrencyFormatter.formatCompact` and for choosing the relative-day label text. |

## Presentation Outputs

The screen renders, top to bottom, each independently loading/erroring
(FR-010):

1. Header: greeting (FR-008), notification entry point (FR-012).
2. Total balance card: compact + full amount (FR-002).
3. Negative-balance warning banner, present iff `OverviewSummary.negativeAccounts.isNotEmpty` (FR-003); tapping "Xem chi tiết" opens the transaction-history screen pre-filtered to that account's group.
4. Accounts section: horizontally scrollable cards (FR-004) + "Xem tất cả" → Kế hoạch tab (FR-005); empty state if `accounts.isEmpty` (FR-009).
5. Recent-transactions section: chronological rows (FR-006) + "Xem tất cả" → the existing full-screen Lịch sử giao dịch route (FR-007); empty state if no records (FR-009).

All new strings are sourced from `AppLocalizations` in both `vi` and `en`
(FR-011); no screen text is hardcoded.

## State Outcomes Per Section

There are **two** independent underlying data sources, not three: the total
balance card and the accounts section both derive from the same
`expenseControlTreeProvider`-backed `OverviewSummary` (they load/fail/succeed
together, by construction, since the total is computed from the same account
list the cards render — this is what keeps them from ever disagreeing, per
data-model.md's invariant); the recent-transactions section is backed by its
own, separate `watchRecent`-based `StreamProvider`. Each of these two sources
is rendered independently via `.when(...)`:

| State | Total balance card + accounts section (shared source) | Recent-transactions section (separate source) |
|---|---|---|
| Loading | `CircularProgressIndicator` in place of the amount and the list | `CircularProgressIndicator` in place of the list |
| Empty (no accounts / no transactions) | Total renders as "0 ₫" (always computable); accounts section shows `EmptyStateView`, no action | `EmptyStateView`, no action |
| Error | `EmptyStateView` with retry action, in place of both the amount and the accounts list | `EmptyStateView` with retry action |
| Data | Compact + full amount; warning banner if applicable; horizontally scrollable `OverviewAccountSummary` cards | `OverviewTransactionItem` rows |

A failure or slow load in the account data MUST NOT block or delay the
recent-transactions render, and vice versa (FR-010) — this is a direct
consequence of the two sources being genuinely independent providers, not a
single combined provider gating the whole screen. Do not introduce a third,
separate provider for the total-balance card alone — it would let the total
and the accounts list disagree if one succeeded and the other didn't.

## Error Contract

Data failures surface a localized, retryable error per affected section
(`EmptyStateView` + `onAction` invalidating that section's provider only).
No raw exception text or financial values are logged, matching the
constitution's logging-discipline rule.

## Navigation Contract

| Trigger | Target |
|---|---|
| "Xem tất cả" (accounts) | `context.go('/expense-control')` (Kế hoạch tab) |
| "Xem chi tiết →" (negative-balance banner) | `Navigator.push(MaterialPageRoute(builder: (_) => ProviderScope(overrides: [selectedTransactionHistoryFilterProvider.overrideWith((ref) => TransactionHistoryFilter.group(accountName))], child: const TransactionHistoryScreen())))` |
| "Xem tất cả" (recent transactions) | `Navigator.push(MaterialPageRoute(builder: (_) => const TransactionHistoryScreen()))` |
| Notification bell | `Navigator.push(MaterialPageRoute(builder: (_) => const NotAvailablePlaceholderScreen(...)))`, matching the existing Hồ sơ notification row exactly |

No new `GoRoute` is registered by this feature beyond replacing `/overview`'s
existing placeholder builder with the real `OverviewScreen`.

**Note on the "Xem chi tiết →" filtered view**: `TransactionHistoryFilter.group`
only matches `expense` records (`transaction_history.dart:79-82`) — this is
existing behavior, unchanged by this feature. For this use case it is the
correct behavior anyway (income cannot cause a negative balance, so filtering
it out does not hide anything relevant), but it means the pushed screen shows
that account's expenses only, not a full ledger including income allocated
into it.
