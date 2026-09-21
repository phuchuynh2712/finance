# Research: Income Entry & Automatic Allocation ("Thu nhập")

No `NEEDS CLARIFICATION` markers remain in Technical Context — spec.md's Clarifications session already resolved every scope-defining unknown (allocation order, insufficient-income behavior, leftover mechanic, savings-receiver scope, uniqueness enforcement layer). This document translates those decisions into concrete implementation choices and records the alternatives considered for each.

## Decision 1: The allocation algorithm is one sequential pass over leaves in `sortOrder`, not two passes (fixed-then-percentage)

**Decision**: A single new pure function, `computeIncomeAllocation(List<ExpenseControlNode> tree, int totalIncome)` (or equivalent working directly over the flattened leaf list), walks every leaf — top-level leaves and every group's children, in the same order `ExpenseControlPlanService.buildTree()` already produces — exactly once, left-to-right/top-to-bottom. For each leaf, in order: compute its formula share (fixed amount as-is; percentage as `(remaining-before-this-item's-original income total) * allocationValue / 100`, using the *original* total income for percentage math per spec.md Acceptance Scenario 4 — "20% of the total income amount entered," not 20% of whatever happens to remain), then add `min(share, incomeRemaining)` to a running per-item delta map and decrement `incomeRemaining` by that same amount. Stop early (skip remaining leaves entirely) the moment `incomeRemaining` reaches 0.

**Rationale**: spec.md's first Clarification is explicit and unambiguous: *"Theo `sortOrder` từ trên xuống, xử lý lần lượt từng khoản (không tách hai lượt fixed-rồi-percentage như logic Envelope cũ)."* This is a deliberate rejection of the retired `Envelope`-era `computeAllocationPreview`'s two-pass shape (fixed pass, then percentage pass) — this feature's algorithm must process items strictly in display order regardless of their `allocationMethod`.

**Alternatives considered**:
- Two-pass (fixed first, then percentage) — the old `Envelope` shape. Rejected per explicit user Clarification; would also produce different numbers than "top-down as displayed" whenever a percentage item appears before a fixed item in `sortOrder`.
- Percentage always computed against the *original* total regardless of processing order (research question resolved by Acceptance Scenario 4's own wording: "exactly 20% of the total income amount entered" — not 20% of a shrinking remainder). This avoids a second ambiguity: whether percentage recalculates against a shrinking base, which would make results depend on how much was already spent by earlier items in a way spec.md's scenarios don't describe. Fixed at "percentage always means % of the original total, income remaining is just a running cap," matching FR-006's wording exactly ("its formula share... or its percentage of the total income amount entered").

## Decision 2: Insufficient income truncates the current item, then halts the entire sequence

**Decision**: The moment a leaf's `min(share, incomeRemaining)` computation yields a value strictly less than `share` (i.e., `incomeRemaining < share`), that leaf receives all of `incomeRemaining`, `incomeRemaining` becomes 0, and the loop stops — no leaf after it in `sortOrder` is evaluated at all (not even a partial/zero allocation is recorded for them; they simply keep whatever balance they already had).

**Rationale**: spec.md's second Clarification: *"khoản đó nhận hết phần thu nhập còn lại (có thể ít hơn công thức của nó), rồi dừng; các khoản sau đó (theo `sortOrder`) không nhận gì cả."* This is a hard stop, not a "skip this one, keep trying the rest" policy — confirmed by the second option in the clarifying question (skip-and-continue) being explicitly declined by the user in favor of "receive remainder then stop."

**Alternatives considered**:
- Skip the underfunded item (give it 0) and continue trying subsequent items with the same remaining income — explicitly rejected by the user's answer.
- Allow the underfunded item to go negative to fully satisfy its formula, borrowing from "future" income — never on the table; conflicts with FR-007's explicit "no item's balance is ever decreased or left negative as a direct result of this allocation step," and Assumptions' note that this feature introduces no new negative-balance scenario.

## Decision 3: The savings-receiver leftover is applied once, after the entire sequential pass, as a separate step

**Decision**: After Decision 1/2's loop completes (either because every leaf was processed, or because it halted early per Decision 2), if `incomeRemaining > 0`, the algorithm looks up whichever single leaf item currently has `isSavingsReceiver == true` (found by a linear scan over the same leaf list — there is at most one, per FR-008/FR-009) and adds the entire remaining amount to that item's running delta (on top of whatever it already received from its own formula in the main pass, per spec.md's Edge Cases: *"The receiver first receives its own formula's share... then separately receives the leftover on top, in the same allocation pass"*). If no leaf has the flag set, `incomeRemaining` is simply not applied anywhere (FR-013) — the function returns it as an explicit "unallocated" amount in its result type rather than silently discarding the information, so a future feature (or this feature's own UI, if useful) can inspect it without needing to re-derive it.

**Rationale**: Directly implements spec.md's third and fourth Clarifications. Keeping this as a distinct step *after* the main loop (rather than folding it into Decision 1's per-item logic) keeps the function's two concerns — "walk the tree distributing by formula" vs. "sweep the remainder to one designated place" — separately testable, matching how `ExpenseControlPlanService`'s existing methods (`computeTotals`, `validateBudget`, `computeItemBalance`) are each a single, focused pure function rather than one do-everything method.

**Alternatives considered**:
- Treating the savings receiver as "just another leaf, processed in its normal `sortOrder` position, that happens to also soak up any leftover from earlier items right there" — rejected because it would make the receiver's position in `sortOrder` matter for whether it receives leftover contributed by *later* items in the sequence (a receiver positioned early would only see leftover from items before it, not after), which contradicts the design's evident intent (in the reference mockup and the user's framing) that the receiver is a global backstop, not a position-dependent one.

## Decision 4: `isSavingsReceiver` is a new boolean column on `ExpenseControlItems`, not a separate table

**Decision**: `IntColumn`/`BoolColumn get isSavingsReceiver => boolean().withDefault(const Constant(false))()` added directly to `lib/core/database/tables/expense_control_items_table.dart`, mirroring exactly how `balance` was added in the prior feature (single-column addition via `m.addColumn`, no new table). Domain-level `ExpenseControlItem.isSavingsReceiver` (required, non-nullable `bool`, mirroring how `balance` is required non-nullable `int`).

**Rationale**: The flag is intrinsic to a single `ExpenseControlItem` row (one boolean per item), not a relationship needing its own table — same reasoning the prior feature used for `balance`. A separate table would require a join for every read of the flag, for no benefit, and would need its own RLS policy from scratch rather than inheriting the parent table's.

**Alternatives considered**:
- A separate `savings_receiver` table holding a single row (user_id → item_id) — considered and rejected as needless indirection for a value that is a property of exactly one row, not a relationship between rows; every place this flag is read is already reading the full `ExpenseControlItem` row anyway (the create/edit dialog, the allocation algorithm's leaf scan).

## Decision 5: Uniqueness ("at most one receiver") is enforced only in `ExpenseControlFormController`'s validation, not as a Drift/Supabase constraint

**Decision**: When the user attempts to save an item with the toggle on, `ExpenseControlFormController` (or its save path) checks the currently-loaded item list for any *other* item already flagged `true`; if found, the save is blocked with an inline error (FR-009) and nothing is written. No `UNIQUE` partial index, no Supabase constraint, no sync-time conflict-detection logic is added for this field.

**Rationale**: spec.md's fifth Clarification is explicit: *"Chỉ validate ở tầng ứng dụng (local)... Không thêm ràng buộc đặc biệt ở tầng dữ liệu/sync cho trường này."* This intentionally accepts the rare multi-device race spec.md's Edge Cases describes (two offline devices each marking a different item, both syncing) as an acceptable last-write-wins-class risk, consistent with how every other field conflict in this app is already handled (no field-level conflict resolution exists anywhere in the current codebase beyond `updated_at`-based last-write-wins at the row level).

**Alternatives considered**:
- A `UNIQUE` partial index (`WHERE is_savings_receiver = true`) at the Drift/SQLite level — this is exactly what the retired `Envelope.isRoundingReceiver` had (per research done during specification: *"enforced via a partial unique index per research.md §3"*). Explicitly rejected by the user this time — a deliberate change from the old approach, not an oversight, per the direct Clarification answer.
- Server-side reconciliation logic to detect and resolve a post-sync double-mark — out of scope per Decision 5 above and the Complexity Tracking entry in plan.md; would require rebuilding sync-worker infrastructure this feature explicitly does not undertake.

## Decision 6: A new `ExpenseControlRepository` method for the bulk balance write, following the existing `saveFormulas` shape

**Decision**: Add one new method to `ExpenseControlRepository` (interface) and its Drift-backed implementation — working name `applyIncomeAllocation(Map<String, int> balanceDeltas)` — that, in a single Drift transaction, for each `(itemId, delta)` pair: reads the item's current `balance`, writes `balance + delta`, and appends one `sync_outbox` row per changed item (mirroring `saveFormulas`'s existing per-id-loop-with-outbox-append shape exactly, per the Constitution's outbox-in-the-same-transaction requirement).

**Rationale**: The existing repository interface has no method shaped for "add a delta to N items' `balance` atomically" — `update()` replaces name/icon/description only and never touches `balance`; `saveFormulas()` is scoped to formula fields and also never touches `balance`. Rather than overloading either of those, a new, narrowly-scoped method keeps each existing method's contract unchanged (Constitution Principle I: single, well-defined responsibility) and makes the new write path's intent explicit in the interface itself.

**Alternatives considered**:
- Widening `saveFormulas`'s `PendingItemEdit` to also carry an optional `balanceDelta` field — rejected because `PendingItemEdit` is explicitly documented as "the data-layer half of the 'Lưu công thức' flow" (a *staged, user-reviewed* edit flow with its own discard/save UX in Kiểm soát chi tiêu); income allocation is a *fire-and-forget* write with no staging or review step (per spec.md's User Story 1: "no separate confirmation or preview step is required beyond saving"). Conflating the two would blur a currently-clean distinction between "an edit the user is actively staging in a dialog" and "a computed result being persisted directly."
- Calling `update()` once per changed leaf item from the income screen's controller directly (no new repository method) — rejected because `update()`'s existing signature takes a full `ExpenseControlItem`, would require the caller to have first re-read every item's latest balance to compute the new value (a race condition against concurrent writes) and would not batch the writes into one transaction/one set of outbox rows, unlike every other existing bulk-write path in this codebase.

## Decision 7: The income-entry screen is new presentation code in `lib/features/expenses/`, reusing `expense_control`'s tree/leaf data, not duplicating it

**Decision**: `IncomeScreen` (new, `lib/features/expenses/presentation/income_screen.dart`) reads the same `expenseControlTreeProvider`/`expenseControlItemsStreamProvider` that `SpendingScreen` and Kiểm soát chi tiêu already read — it does not introduce a second query path for the same data. Its own screen-local state (the list of income source line items being entered) lives in a new, screen-scoped controller/provider (`income_providers.dart`), separate from any `expense_control` state, since income source line items are transient UI-only data with no domain-layer counterpart (per spec.md's Key Entities: *"Exists only transiently while the user is on this screen"*).

**Rationale**: Mirrors exactly how the prior "Thu chi" feature split `SpendingScreen` (presentation, in `expenses/`) from `ExpenseControlPlanService`/`computeItemBalance` (domain logic, in `expense_control/`) — reading the same tree, not maintaining a parallel one. Reusing the existing stream avoids any risk of the income screen and "Thu chi" ever showing different balances for the same item due to two independent read paths.

**Alternatives considered**:
- A new repository/provider specifically for "leaf items eligible for allocation" (e.g. pre-filtered to exclude groups) — considered, but rejected as an unnecessary indirection: the allocation algorithm (Decision 1) already needs the full tree shape (to know which items are leaves vs. groups, in the correct traversal order) exactly as `ExpenseControlPlanService.buildTree()` already produces it, so a separate "leaves-only" provider would just be filtering data the existing tree provider already exposes correctly.

## Decision 8: Currency input parsing reuses the existing pattern from the retired `PlanController`, adapted (not copied) for this feature's simpler needs

**Decision**: Each income source amount field is a plain numeric `TextField`, stripped of non-digit characters on change and parsed to `int` (matching `CurrencyFormatter`'s whole-VND-unit convention, no decimal places), formatted for display via the existing shared `CurrencyFormatter`. No live-preview-while-typing recomputation against the allocation algorithm is needed (unlike the retired `PlanController`, which recomputed a live preview on every keystroke) — per spec.md's User Story 1, this screen has no preview step; allocation only runs once, on save.

**Rationale**: The retired `PlanController`'s live-preview-on-every-keystroke behavior existed specifically to support the old `PlanScreen`'s live allocation preview UI, which this feature's spec explicitly does not have (spec.md: "no separate confirmation or preview step is required beyond saving"). Reusing that pattern's *input-parsing* mechanics (strip-and-parse) is reasonable; reusing its *live-recompute-on-every-keystroke* architecture would be over-engineering for a feature with no preview UI to drive.

**Alternatives considered**: A dedicated `TextInputFormatter` for grouped-thousands live formatting while typing — out of scope; the reference design's mockup shows a plain numeric field with no live-grouping-while-typing shown, and no acceptance scenario requires it.

## Decision 9: If a sync race transiently produces more than one savings-receiver-marked leaf, the allocation algorithm picks the first match in `sortOrder` and treats the rest as unmarked for that pass

**Decision**: When the allocation algorithm's leftover step (data-model.md step 4) scans for the marked leaf, if it finds more than one, it uses the first one encountered in the same `sortOrder` traversal already used for the main pass, and ignores any other marked leaf for that allocation only. This tie-break does not attempt to detect, correct, or warn about the underlying multi-mark state — it exists solely so the allocation function has deterministic, well-defined behavior if that rare state is ever encountered, without requiring any new infrastructure.

**Rationale**: spec.md's Edge Cases explicitly deferred this exact question to planning: *"the next income save's leftover-allocation behavior when more than one item is marked is out of scope to specify further here (an implementation detail `/speckit-plan` may need to pick a tie-break for, e.g. first match in `sortOrder`...)."* `sortOrder` is the natural choice because it's the same ordering already driving every other part of this algorithm (research.md Decision 1) — no new ordering concept is introduced just for this rare case.

**Alternatives considered**:
- Splitting the leftover evenly across every marked leaf — rejected as needless complexity for a state the application layer already prevents under normal operation (research.md Decision 5) and that this feature is not attempting to detect or actively manage.
- Treating multiple marks as an error that blocks the entire income save — rejected because it would make a rare, accepted background-sync artifact (not a user action taken in this save) block an unrelated, otherwise-valid income entry; the user attempting to save income did nothing wrong.
