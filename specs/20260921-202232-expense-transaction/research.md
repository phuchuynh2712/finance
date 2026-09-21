# Phase 0 Research: Expense Transaction Recording

## Decision 1: New table shape and name

**Decision**: Add a single new Drift table, `FinancialTransactions` (Supabase: `financial_transactions`), backing both Income Transaction and Expense Transaction (spec.md's Key Entities). Columns:

| Column | Type | Notes |
|---|---|---|
| `id` | `TextColumn` (uuid) | Primary key, generated app-side via `package:uuid`, matching `expense_control_items`' own id convention. |
| `user_id` | `TextColumn` | Owner, matching `expense_control_items.user_id`'s convention — required for the Supabase RLS policy. |
| `expense_control_item_id` | `TextColumn` | The budget item this transaction affected. No Drift-level FK declared (matching the codebase's existing convention — see Decision 2), but a real Postgres FK on the Supabase side (matching `expense_control_items.parent_id`'s own FK precedent). |
| `direction` | `TextColumn` via `textEnum<TransactionDirection>()` | `income` \| `expense` — same `textEnum` pattern already used for `expense_control_items.allocation_method`. |
| `amount` | `IntColumn` | Always a positive whole-VND integer regardless of direction; `direction` alone carries the sign meaning (spec.md FR-014). Storing a signed amount was considered and rejected — see Decision 3. |
| `occurred_at` | `DateTimeColumn` | The single timestamp FR-014 requires. One income allocation producing several rows gets the SAME `occurred_at` across all of them (Decision 4). |
| `created_at` | `DateTimeColumn`, default `currentDateAndTime` | Matches `expense_control_items`' own audit-column convention (research.md consistency, not spec-required). |

Indexed on `(user_id, occurred_at)` — a Drift `@TableIndex` (mirroring `expense_control_items`' own `_user_id_idx` pattern) and a matching Postgres `create index` in the Supabase migration (mirroring that migration's own two `create index` statements). This is the hot query a future Report feature will run constantly ("all transactions for this user in month M") — skipping the index means a full-table scan on every report open.

`direction`'s `textEnum` has exactly two variants, `income` and `expense` (not `credit`/`debit`, not `in`/`out`) — committed here since the enum's text values are what gets persisted into every stored row and into Supabase.

**Rationale**: spec.md's Key Entities section explicitly names Expense Transaction and Income Transaction as two shapes of one underlying "Financial Transaction" record, and FR-014 spells out the exact minimal column set (amount, budget item, direction, timestamp). One table is simpler than two, avoids duplicating the outbox-write/RLS/index boilerplate twice, and is exactly what a future Report feature wants to query as a single source (spec.md's own framing).

**Alternatives considered**:
- **Two separate tables** (`income_transactions`, `expense_transactions`): rejected — spec.md explicitly frames these as the same shape distinguished only by direction; two tables would double every piece of plumbing (migration, RLS policy, outbox entity-table string, index) for no query benefit, since a future Report feature would need to `UNION` them back together anyway.
- **Reusing `sync_outbox`'s payload as the only history**: rejected — outbox rows are pruned/marked-synced over time and are an implementation detail of the sync mechanism, not a queryable domain table; a Report feature has no business reading sync plumbing.

## Decision 2: No Drift-level foreign key from `financial_transactions` to `expense_control_items`

**Decision**: `expense_control_item_id` is a plain `TextColumn`, no `references()` call at the Drift layer. A real Postgres foreign key IS declared on the Supabase migration side.

**Rationale**: Confirmed via direct inspection of `expense_control_items_table.dart` (research phase) that the existing codebase has zero precedent for a Drift-level FK anywhere — even `expense_control_items.parent_id`, a self-referencing relationship, is a bare `TextColumn`. Relational integrity for that column is enforced only at the domain/repository layer. This feature follows the same established convention rather than introducing a new pattern for one table. The Postgres side already has a real FK precedent (`expense_control_items.parent_id references expense_control_items (id)`), so `financial_transactions.expense_control_item_id references expense_control_items (id)` follows that existing convention exactly.

**Alternatives considered**: Introducing a Drift FK for this one table — rejected as an unjustified, unprecedented deviation for a single table when the rest of the schema has never used one; Drift FKs also complicate testing (would need every leaf item to exist before any transaction test fixture, adding friction with no correctness benefit the repository layer doesn't already provide).

## Decision 3: Amount is always stored positive; `direction` carries the sign

**Decision**: `amount` is a positive `IntColumn` in all rows. Deriving "money in vs. money out" is always done by reading `direction`, never by the sign of `amount`. Enforced at the storage layer too, not just in application code: the Postgres migration adds `check (amount > 0)` on `financial_transactions.amount`, the same style of invariant `expense_control_items`' own migration already uses (`check (char_length(name) > 0)`, `check (allocation_method in (...))`).

**Rationale**: This matches how the app already displays money everywhere (`CurrencyFormatter.format(int amountInVnd)` — confirmed it takes a plain magnitude, not a signed delta) and avoids an entire class of double-negative bugs (e.g. an expense transaction incorrectly holding a negative amount, then `balance -= (-amount)` accidentally adding instead of subtracting). A future Report feature's "tổng Thu nhập"/"tổng Chi tiêu" cards (per `bao-cao-spec.md`, preserved as this feature's own forward-looking context) sum by direction anyway, so a signed-amount representation would have to be un-signed again at read time regardless.

**Alternatives considered**: Signed `amount` (negative for expense): rejected per Rationale above — adds a sign-inversion bug surface for zero query benefit.

## Decision 4: One `occurred_at` per income-allocation event, not per row

**Decision**: When one "Lưu thu nhập" action produces multiple Income Transaction rows (one per budget item the allocation touched, mirroring `IncomeAllocationResult.deltas`' existing one-entry-per-item shape), every row created by that single action shares the exact same `occurred_at` timestamp (captured once, before the loop that creates each row).

**Rationale**: These rows represent one user-facing event (one tap of "Lưu thu nhập"), not several independent events that happened to occur at slightly different microseconds due to loop iteration order. A future Report feature grouping "how many times did the user log income this month" would get a spuriously inflated count if timestamps drifted by iteration. This mirrors `applyIncomeAllocation`'s own existing pattern of computing `now` once and reusing it for every row in the same call (confirmed: the current balance-update loop already does this for `updated_at`).

**Alternatives considered**: A fresh `DateTime.now()` per row: rejected — introduces meaningless microsecond-level skew across rows that are logically one event, and (rare but real) risks two rows landing in different calendar seconds near a second boundary, which would be a visible inconsistency if a report ever displayed "recorded at" per row.

## Decision 5: Recording flow for expense — one atomic transaction, new repository method

**Decision**: Add `Future<void> recordExpense({required String itemId, required int amount})` to `ExpenseControlRepository`/`ExpenseControlRepositoryImpl`. Internally, in a single `_db.transaction()`:
1. `customUpdate` to atomically decrement the item's `balance` by `amount` (same `customUpdate`-not-`customStatement` requirement as `applyIncomeAllocation`, for the same Drift stream-invalidation reason — research.md's prior feature already discovered and documented this).
2. Insert one `financial_transactions` row (`direction: expense`, the given `amount`, `occurred_at: DateTime.now()`).
3. Append one `sync_outbox` row for the balance-changed `expense_control_items` row (existing pattern) AND one `sync_outbox` row for the newly-inserted `financial_transactions` row (new, same `_appendOutbox` helper, different `entityTable` string).

**Rationale**: FR-009 requires (a) and (b) atomic; wrapping both in the same `_db.transaction()` as (c)'s outbox appends is exactly the existing pattern every other write method in this repository already follows (`create`, `update`, `saveFormulas`, `applyIncomeAllocation` all do this) — no new pattern needed, just one more table's worth of the same shape.

**Alternatives considered**: A separate `TransactionRepository` distinct from `ExpenseControlRepository`: considered, but rejected for this feature's scope — the write is intrinsically coupled to an `expense_control_items` balance mutation (same atomic transaction, same table lock), so splitting the repository would either force two repositories to share one Drift transaction (awkward, `AppDatabase`-level plumbing) or reintroduce the read-then-write race the atomicity requirement exists to prevent. A read-side `FinancialTransactionRepository` (for the future Report feature) is a separate, additive concern not needed by this feature's own write path.

## Decision 6: Recording flow for income — extend `applyIncomeAllocation`, not a second top-level call

**Decision**: `applyIncomeAllocation`'s signature stays exactly as it is today — `Future<void> applyIncomeAllocation(Map<String, int> balanceDeltas)`, no parameter added or changed. Only its *implementation* grows: inside its existing single `_db.transaction()`, it additionally inserts one `financial_transactions` row per non-zero entry in the map (`direction: income`, that entry's amount, the one shared `occurred_at` per Decision 4). `IncomeFormController.save()`'s call site does not change at all — it already computes and passes exactly the `Map<String, int>` this needs; no new data has to flow from the Income screen into the repository.

**Rationale**: Confirmed via research that `IncomeFormController.save()` already discards each `IncomeSourceRow`'s individual name/amount once it computes `result.deltas` — and FR-014 only requires recording per-item history, not per-income-source history, so `result.deltas` (item id → amount) is already sufficient input; no new data needs to flow from the Income screen into the repository. Keeping this inside `applyIncomeAllocation`'s existing transaction — rather than a second, separate call from `IncomeFormController.save()` — is what makes Decision 7's atomicity requirement (spec.md Clarifications: balance updates and history rows must succeed/fail together as one unit) trivially true: they are quite literally the same Drift transaction, not two calls the caller must remember to wrap together.

**Alternatives considered**:
- **A second repository call from `IncomeFormController.save()`** (e.g. `applyIncomeAllocation(deltas)` then separately `recordIncomeHistory(deltas)`): rejected — this is exactly the "two separate top-level awaits" shape the atomicity Clarification (FR-013) exists to prevent; a failure between the two calls would leave balances updated with no matching history, which spec.md explicitly calls out as never acceptable.
- **Passing `List<IncomeSourceRow>` into `applyIncomeAllocation` for richer history**: rejected — spec.md's Clarifications session explicitly resolved this exact question in the opposite direction (no merchant/note-level detail beyond the minimal FR-014 shape), and per-source detail was never part of FR-014's minimal column set; adding it would be scope creep beyond what was clarified.

**Guardrail for future changes**: if a later refactor moves the history-row insert out of `applyIncomeAllocation`'s own `_db.transaction()` — e.g. into a separate call from a wrapping service, "to separate concerns" — FR-013's atomicity requirement is silently violated even though this method's signature never changes. Any code review touching this method's internals MUST confirm the history insert is still inside the same transaction as the balance `customUpdate` calls, not just that the method still compiles and its signature is unchanged.

## Decision 7: Migration — schema v4 → v5

**Decision**: Bump `AppDatabase.schemaVersion` from `4` to `5`. Add a new `if (from <= 4) { await m.createTable(financialTransactions); }` block to `onUpgrade`, following the already-fixed cumulative-`<=` pattern (confirmed correct in the current codebase — the historical `==`-vs-`<=` bug from a prior feature is already resolved and must not be regressed).

**Rationale**: A brand-new table only needs `m.createTable`, unlike the prior features' `m.addColumn` cases — simpler migration, same cumulative-condition discipline.

**Alternatives considered**: None — this is the only correct migration shape for adding a new table in this codebase's established Drift migration convention.

## Decision 8: UI picker for "Trừ vào khoản nào" — reuse `ExpenseControlPlanService`'s existing leaf-flattening, made public

**Decision**: Promote `ExpenseControlPlanService._flattenLeaves(tree)` (currently private, already used internally by `computeIncomeAllocation`) to a public method (or add a thin public wrapper) so the "Chi tiêu" screen's presentation layer can call it directly to build the horizontal leaf-item picker list, in the same top-to-bottom/group-interleaved display order the rest of the app already uses.

**Rationale**: This exact leaf-flattening logic already exists and is already tested (via `computeIncomeAllocation`'s own test suite) — reusing it avoids a second, potentially inconsistent implementation of "what counts as a leaf, in what order" between the Income screen's internal allocation logic and this new screen's picker UI. `ExpenseControlNode.isGroup` (`children.isNotEmpty`) is the existing public primitive for leaf/group distinction; `_flattenLeaves` already builds on top of it correctly (including group-interleaved ordering), which a naive `items.where((i) => ...)` reimplementation in the presentation layer would risk getting subtly wrong (e.g. ordering).

**Alternatives considered**: Reimplementing leaf-filtering directly in the new screen's provider/controller: rejected — duplicates tested logic for no benefit, risks the two call sites (allocation vs. picker) silently diverging on what "leaf" or "display order" means if one is changed later without the other.

## Decision 9: Currency keypad input — no reusable parse utility exists; build screen-local digit accumulation

**Decision**: The "Chi tiêu" screen's custom keypad accumulates raw digits into local state (a `String` or `int` amount), exactly the way the existing Income screen's amount field already does while focused (confirmed: `CurrencyFormatter` has no reverse/parse method — `format(int) -> String` only, one direction). Live-formatted display (grouped digits) is applied via `CurrencyFormatter.format` for the read-only large amount display at the top of the screen (which is not a `TextField` the user types into directly, unlike the Income screen — this screen's input method is exclusively the custom keypad grid, so there's no cursor-position concern `CurrencyFormatter`'s live-reformatting would fight, unlike Decision 8 of the income-allocation feature's own research).

**Rationale**: No existing shared "currency text input controller" utility exists in `lib/core/formatting/` to reuse or extend — the Income screen's own approach (raw digits while editing, `CurrencyFormatter.format` on blur) was a per-screen convention, not a promoted shared widget. Given this screen's input is a fully custom keypad (never a system-keyboard `TextField`), the amount can be kept formatted at all times without any cursor-jump risk, which is actually simpler than the Income screen's focus-based toggle.

**Alternatives considered**: Extracting a shared `CurrencyInputController` now: rejected as premature — this would be the second screen to need this exact logic (after Income), which is a reasonable trigger for extraction, but doing so is a refactor of an already-shipped, tested screen that's out of this feature's stated scope; noted here as a legitimate future cleanup, not blocking this feature.

## Decision 10: Reused widgets

- `EmptyStateView` (`lib/core/widgets/empty_state_view.dart`) for the "chưa có khoản nào" empty state in the "Trừ vào khoản nào" picker area, matching `SpendingScreen`'s own existing `tree.isEmpty` empty-state usage (spec.md Edge Cases).
- The "Thu nhập" button's existing `Navigator.push(MaterialPageRoute(builder: (context) => const IncomeScreen()))` pattern on `SpendingScreen` is the direct template for replacing the "Chi tiêu" button's `onPressed` (currently `_openPlaceholder(...)`), confirmed via direct comparison of both call sites in `spending_screen.dart`.

## Decision 11: Known mockup rendering inconsistency (dark-mode preview banner)

Per spec.md's Assumptions, `chi-tieu-package/screen-dark.png`'s negative-balance preview banner renders with the same light-looking danger-soft background as the light-mode screenshot rather than a dark-adjusted tint. This is the same category of mockup artifact already identified and resolved in the prior Profile-settings feature (a designer-produced dark variant not fully re-themed from its light source) — implementation MUST use the app's existing dark-mode `dangerSoft`/`dangerFg` token pair (`AppSemanticColors`), not replicate the screenshot's literal color pixel-for-pixel.
