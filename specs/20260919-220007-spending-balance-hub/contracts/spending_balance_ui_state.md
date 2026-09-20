# UI Contract: Spending Balance Hub Screen State & Envelope Retirement

This feature's network/API contract is an additive column plus several dropped tables/view on the remote schema (see data-model.md). What this file documents is the **contract between `SpendingScreen`/`OverviewScreen` and the existing `ExpenseControlRepository`/`ExpenseControlPlanService`**, the navigation contract for the four placeholder entry points, and the explicit deletion contract for everything Envelope-related, so implementation matches research.md's decisions exactly.

## Read-side contract: balance tree assembly

`SpendingScreen` MUST read from the same `expenseControlRepositoryProvider.watchAll()` stream (or an equivalent provider already wrapping it) that Kiểm soát chi tiêu uses — NOT a new provider, NOT `envelopesStreamProvider`. It MUST build its tree via the existing `ExpenseControlPlanService.buildTree()` (no `pendingEdits` overlay needed here, since this screen never stages edits).

| Tree node | Displayed balance |
|---|---|
| Leaf (`node.children.isEmpty`) | `node.item.balance` directly |
| Group (`node.children.isNotEmpty`) | Live sum of `node.children.map((c) => c.balance)` — computed by a new `ExpenseControlPlanService` method, never read from the group item's own `balance` column |

`ExpenseControlRepository`'s existing method signatures (`watchAll`, `getAll`, `create`, `update`, `delete`, `reorderTopLevel`, `saveFormulas`) are **unchanged in shape** by this feature — `balance` flows through automatically once it's a field on `ExpenseControlItem`, per data-model.md. No new repository method is added.

## Explicit non-write contract

`SpendingScreen` MUST NOT call `ExpenseControlRepository.create()`, `.update()`, `.delete()`, `.reorderTopLevel()`, or `.saveFormulas()` — this screen is entirely read-only with respect to `ExpenseControlItem` (spec.md FR-005). The only write this feature performs anywhere is the one-time schema migration's column default (data-model.md) — no application code path writes a `balance` value.

## Navigation contract: placeholder entry points

| Trigger | Destination | Back behavior |
|---|---|---|
| Tap "Thu nhập" | `Navigator.push` → generalized placeholder screen (research.md Decision 4), parameterized with an income-specific icon/title/message | Default `MaterialPageRoute` back button (automatic) |
| Tap "Chi tiêu" | Same placeholder screen, parameterized with an expense-specific icon/title/message | Same |
| Tap "Xem lịch sử giao dịch" | Same placeholder screen, parameterized with a history-specific icon/title/message | Same |
| "Tổng quan" tab selected | The same placeholder screen rendered as the tab's own branch content (not pushed — it's a bottom-nav tab, not a sub-navigation target), parameterized with a "Tổng quan"-specific icon/title/message | N/A — it's a tab, not a pushed route; no back button |

None of these destinations perform any repository read or write — they are static placeholder content only (spec.md FR-009, FR-017).

## Deletion contract: Envelope and everything built on it

The following MUST have zero remaining references anywhere under `lib/` once this feature is complete (spec.md FR-015, FR-016, FR-018, FR-019, SC-006):

| Deleted symbol/file | Replacement (if any) |
|---|---|
| `Envelope`, `EnvelopeRepository`, `EnvelopeRepositoryImpl`, `envelopeRepositoryProvider`, `envelopesStreamProvider` | None — `ExpenseControlItem`/`expenseControlRepositoryProvider` is the sole balance source going forward |
| `AllocationEvent`, `AllocationEventLine`, `AllocationRepository`, `AllocationRepositoryImpl`, `allocationRepositoryProvider`, `computeAllocationPreview` | None — a future feature designs income allocation fresh against `ExpenseControlItem` if/when needed |
| `ExpenseEntry`, `ExpenseRepository`, `ExpenseRepositoryImpl`, `expenseRepositoryProvider`, `expensesStreamProvider`, `computeOverspend`, `EnvelopeCoverage` | None — a future feature designs expense recording fresh against `ExpenseControlItem` |
| `ExpenseFormScreen`, `ExpenseFormController` | None — no expense-recording UI exists anywhere in the app until a future feature builds one |
| `PlanScreen`, `PlanController`, `planControllerProvider` | None — no income-allocation UI exists anywhere in the app; `OverviewScreen`'s FAB that led here is also removed |
| `OverviewScreen`'s old envelope-list body + FAB | The shared placeholder screen (Decision 4), rendered as "Tổng quan"'s tab content |
| `lib/features/envelopes/` (entire directory) | Deleted; no successor directory — its one still-needed concept (`ExpenseControlItem.balance`) already lives in `lib/features/expense_control/` |

`app_router.dart` MUST NOT contain any route to `PlanScreen` after this feature ships. (No `EnvelopesScreen`/`EnvelopeFormScreen` files exist in the repo — confirmed via `lib/features/envelopes/` directory listing — so no separate deletion task is needed for them.)

## Explicitly unchanged contracts

- `ExpenseControlRepository`'s method signatures and semantics — no shape change (see above).
- `ExpenseControlPlanService.buildTree()`/`computeTotals()`/`validateBudget()` — called by this feature only via `buildTree()`; the new balance-sum method is additive, not a modification of these existing methods' behavior.
- `HistoryPlaceholderScreen`'s underlying `EmptyStateView` composition pattern — reused (now via the moved/generalized `NotAvailablePlaceholderScreen`), not replaced (research.md Decision 4).
