# Phase 0 Research: Monthly Report Screen

## Decision 1: Data source — reuse `watchTransactionHistory`, no repository change

**Decision**: The Report screen's totals and per-item breakdown are both built
on top of the existing `TransactionHistoryRepository.watchTransactionHistory
({required start, required end})`. No new repository method is required.

**Rationale**: `watchTransactionHistory` already returns both `income`- and
`expense`-direction `TransactionHistoryRecord`s for a date range, unfiltered
by direction (confirmed by reading
`lib/features/expense_control/domain/transaction_history_repository.dart`
and its existing consumer, `buildTransactionHistoryView` in
`lib/features/expenses/application/transaction_history.dart`, which does its
own direction filtering downstream). This is exactly the shape needed: one
query per month, both directions, already indexed and bounded by the
existing `(user_id, occurred_at)` pattern established for this repository.

**Alternatives considered**: A new `watchMonthlySummary`-style aggregate
method on the repository (mirroring how `watchRecent` was added for the
Overview feature) — rejected because the existing method already returns
everything needed; adding a second method would duplicate a query the
repository already exposes, for no benefit.

## Decision 2: Month selection — a new, screen-scoped provider; reuse the existing month-math helpers

**Decision**: Add `selectedReportMonthProvider`, a
`StateProvider.autoDispose<DateTime>` seeded with `monthStart(DateTime.now())`
— structurally identical to the existing
`selectedTransactionHistoryMonthProvider` in
`lib/features/expenses/presentation/transaction_history_providers.dart`, but
a distinct provider instance. Reuse `monthStart`/`nextMonth`/`previousMonth`/
`canAdvanceMonth` from `lib/features/expenses/application/transaction_history.dart`
as-is — no new month-math is written.

**Rationale**: The Report tab and a pushed `TransactionHistoryScreen` are
independent pieces of UI that both happen to need "a selected month," but a
user's month selection on one must not silently move the other (e.g.
Overview pushes `TransactionHistoryScreen` pre-filtered and mid-navigation
on a specific month for the negative-balance banner; that must not change
what the Report tab is showing, and vice versa). Sharing the exact provider
instance would cause that cross-contamination. Duplicating the month-math
functions themselves, by contrast, would be unjustified duplication of pure,
already-tested logic — only the piece of *state* (which month is currently
selected) needs to be separate, not the arithmetic.

**Alternatives considered**: Reusing
`selectedTransactionHistoryMonthProvider` directly — rejected for the
cross-contamination reason above. A `.family`-keyed shared "current month"
provider parameterized by a screen id — rejected as needless indirection for
two callers.

## Decision 3: Report tab's month selection persists across tab switches (`.autoDispose` is still correct here)

**Decision**: `selectedReportMonthProvider` uses `.autoDispose`, matching the
existing pattern, and this is explicitly confirmed — not silently
inherited — to give the intended behavior: **the selected month persists
when the user switches to another tab and back, and only resets on
sign-out** (full shell teardown), not on every tab switch.

**Rationale**: The Report tab lives inside
`StatefulShellRoute.indexedStack` (`lib/core/router/app_router.dart`).
`IndexedStack`-based shell branches stay mounted (not unmounted) when the
user switches to a different tab — only their visibility toggles. Riverpod's
`.autoDispose` tears a provider down when its last listener unsubscribes,
which happens on *widget unmount*, not on *visibility change*; since the
Report branch's widget subtree is never unmounted by a mere tab switch, the
provider's state is never lost by one. It only resets when the branch is
actually unmounted, which in practice means sign-out/shell teardown — the
same behavior already implicitly relied on by
`selectedTransactionHistoryMonthProvider`'s sibling pattern, just now
confirmed as intentional rather than incidental for a tab (as opposed to a
pushed screen, where autoDispose's more frequent reset-on-pop is the whole
point).

**Verification required**: A widget test that selects a past month on the
Report tab, switches to a different tab, switches back, and asserts the
previously-selected month is still shown (tasks.md T0xx).

**Alternatives considered**: A non-autoDispose provider — rejected as
unnecessary; the IndexedStack structure already gives the wanted lifetime
for free, and diverging from the established `.autoDispose` pattern would
need its own justification this doesn't have. A provider explicitly reset
on every `didChangeDependencies`/tab-select — rejected, that would actively
work against the desired "still on August" behavior.

## Decision 4: Two independent providers, not one combined `AsyncValue`, for totals vs. breakdown

**Decision**: Split the derived data into two providers:

- `reportTotalsProvider` (`family<DateTime>`) — depends only on
  `transactionHistoryRecordsProvider(month)` (the existing, reused
  family-keyed stream provider already defined in
  `transaction_history_providers.dart`). Produces the two total amounts.
- `reportBreakdownProvider` (`family<DateTime>`) — depends on
  `transactionHistoryRecordsProvider(month)` **and**
  `expenseControlTreeProvider` (`lib/core/di/expense_dependencies.dart`).
  Produces the per-item list.

**Rationale**: Totals only need the month's transaction records; the
per-item breakdown additionally needs the current expense-control tree (to
resolve each item's current name and parent-group name). If these were one
combined provider awaiting both inputs, a slow or still-loading tree would
delay the totals cards from appearing even though they don't need the tree
at all — regressing the same "independent data sources, each its own
provider, so a slow one never blocks the other's render" principle the
Home Overview feature's plan.md already established (its balance/accounts
summary vs. recent-transactions split). Reusing that exact reasoning here
keeps the two features' loading-state UX consistent.

## Decision 5: Item usage percentage is intentionally month-isolated (no rollover) — recap of the spec-phase decision

**Decision** (carried over from spec.md's Assumptions, restated here because
it drives the computation): for an item with income allocation in the
selected month, `usagePercent = spentThisMonth / allocatedThisMonth * 100`,
using only that month's own `income`- and `expense`-direction transaction
amounts for that item. It does **not** read `ExpenseControlItem.balance`
(a lifetime-cumulative field, confirmed in
`expense_control_repository_impl.dart`'s `applyIncomeAllocation`/
`recordExpense`, which only ever increment/decrement it — never reset it)
and does not reconstruct a historical point-in-time balance for past months.

**Rationale**: verified directly against the write paths in
`expense_control_repository_impl.dart`: `applyIncomeAllocation` inserts one
dated `financial_transactions` row per leaf per income save
(`direction: income`, `expenseControlItemId`, `amount: delta`,
`occurredAt: now`); `recordExpense` inserts one dated row per expense
(`direction: expense`). Both are already surfaced through
`TransactionHistoryRecord`. A month-isolated sum of each direction, per
item, is therefore already fully supported by existing data with no new
write path or schema; a rollover-inclusive version would require
reconstructing each item's balance as of an arbitrary past month boundary,
which nothing in the codebase currently computes and which is out of scope
per spec.md's Assumptions.

## Decision 6: An item with expense activity but zero allocation this month shows a distinct state, not a percentage

**Decision**: When `allocatedThisMonth == 0` and `spentThisMonth > 0`, the
item's breakdown row exposes `usagePercent: null` (rather than attempting a
division), and the presentation layer renders a distinct "not allocated
this month" label instead of a percentage or bar.

**Rationale**: spec.md FR-014, resolved directly with the user — see
spec.md's Edge Cases. This is a common case (any month a fresh income entry
wasn't saved into, while spending continued from an earlier balance), not a
rare corner case, so it must be a first-class, deliberately designed state,
not a silently-produced `Infinity`/divide-by-zero value.

## Decision 7: Overspend (usage over 100%) — bar fill capped, color changes, exact percentage still shown as text

**Decision**: The usage indicator's fill width is `min(usagePercent, 100)%`
of the bar's track width; the bar's fill color switches to the app's
existing `danger`/`dangerFg` semantic color when `usagePercent > 100`
(otherwise the existing `primary`/blue fill color, matching
`reference/theme-tokens.json`'s already-captured light/dark token pairs).
The percentage shown as text next to/above the bar is never capped — a
150%-used item shows "150%" in text even though its bar visually stops at
full width.

**Rationale**: FR-013 allows a percentage above 100% (spending more than
was allocated to an item this month is a real, expected scenario the report
should surface, not hide). A bar cannot geometrically extend past its own
container without look broken or requiring the whole row's layout to
resize unpredictably, so the fill is capped while the number is not — the
user always sees the true figure in text, and the color change gives an
at-a-glance overspend signal without needing to read the number. This
mirrors the same danger/success semantic-color pattern already established
by the month totals' income/expense cards in the source design package.

**Alternatives considered**: Letting the bar visually overflow its track —
rejected, breaks layout predictability. Showing only "100%+" without the
exact figure — rejected, loses information FR-013 requires ("what
percentage... has been used").

## Decision 8: `formatPercent` is the correct, already-established percent formatter to reuse

**Decision**: Use `String formatPercent(double value)` from
`lib/core/formatting/percent_formatter.dart` (takes a 0–100-scale double,
e.g. `45.0` → `"45"`) to render the usage percentage text.

**Correction**: an earlier automated pass over this codebase during
research reported this function as unused anywhere in `lib/`. That is
incorrect — it is directly imported and called today in
`lib/core/router/app_router.dart` (`import
'package:finance/core/formatting/percent_formatter.dart';` near the top of
the file, used as `formatPercent(blockedTotal)` inside
`_DiscardPromptDialogState.build()`'s over-budget error message). This
research.md records the corrected fact: `formatPercent` is an existing,
already-in-use shared utility, consistent with Constitution Principle III's
requirement that figures be formatted via a single shared utility rather
than ad hoc string interpolation — the Report screen's usage percentage
reuses it rather than introducing a second percent-formatting path.

## Decision 9: New pure domain method for leaf → parent-group-name resolution, added to the existing `ExpenseControlPlanService`

**Decision**: Add one new method to
`lib/features/expense_control/domain/expense_control_plan_service.dart`
(e.g. `String? groupNameFor(List<ExpenseControlNode> tree, String leafId)`)
that, given the already-built tree, returns the display name of the
top-level node containing `leafId` as a child, or `null` when `leafId` is
itself a top-level item with no parent group (a standalone leaf — e.g. the
design mockup's "Tiết kiệm"/"Sức khoẻ" rows, which are their own top-level
items, not children of a bigger group).

**Rationale**: no existing method performs this lookup —
`flattenLeaves` deliberately discards which parent `ExpenseControlNode`
each leaf came from. `ExpenseControlPlanService` already owns every other
piece of tree-shape logic (`buildTree`, `flattenLeaves`,
`computeItemBalance`) and is explicitly documented as the pure,
framework-independent owner of tree-building; this is squarely inside its
existing charter, keeps tree-walking logic in one already-tested place, and
matches the precedent the Home Overview feature already established
(`ExpenseControlPlanService.computeItemBalance` reused cross-feature from
`expenses/`) — this service's `domain/` location is already an approved
cross-feature import, so calling this new method from the Report feature's
application layer introduces no new architecture exception.

**Alternatives considered**: resolving group name from
`TransactionHistoryRecord.displayGroupName` instead — rejected: that field
is only populated for `expense`-direction transactions
(`recordExpense` resolves and stores it via `_groupNameFor`); `income`
transactions inserted by `applyIncomeAllocation` do not set it, which would
make an allocated-but-unspent item (spec.md Acceptance Scenario 2 of User
Story 3) unable to show its group name at all. Resolving live from the
already-loaded tree avoids this asymmetry entirely and, as a secondary
benefit, always reflects an item's *current* name/grouping rather than a
name snapshotted whenever a past transaction happened to be written
(consistent with spec.md's Assumptions).

## Decision 10: New usage-bar widget is feature-local, not `core/widgets/`

**Decision**: The new progress/usage-bar presentational widget is added
under `lib/features/expenses/presentation/widgets/`, not `core/widgets/`.

**Rationale**: no existing progress-bar widget exists anywhere in the app
(verified: no match for "progress"/"bar" in
`expense_control/presentation/widgets/` or `core/widgets/`). Per the
Constitution's Recommended Architecture, "something belongs in `core/` only
if it is used by two or more features" — today this widget has exactly one
caller (the Report screen). It stays feature-local until a second feature
needs the same presentational pattern, at which point promoting it to
`core/widgets/` is a pure move with no behavior change.

## Decision 11: Bottom-nav icon change — `LucideIcons.pieChart` confirmed available

**Decision**: `lib/core/router/app_router.dart`'s fourth
`NavigationDestination`'s icon changes from `LucideIcons.history` to
`LucideIcons.pieChart`.

**Verification**: confirmed present in the installed `lucide_icons` package
version (`0.257.0`, pinned in `pubspec.lock`) —
`static const IconData pieChart = const LucideIconData(0xf44b);` in that
package's `lib/lucide_icons.dart`. No dependency version bump needed.

## Decision 12: Route path stays `/history`; only its builder changes

**Decision**: The existing `GoRoute(path: '/history', ...)` keeps its path
unchanged. Only its `builder` changes, from
`NotAvailablePlaceholderScreen(...)` to the new `ReportScreen()` — the same
pattern already used when `/overview`'s placeholder was replaced.

**Rationale**: nothing in spec.md requires a URL/path rename (the tab's
*label* is already "Báo cáo" — only its icon and screen content are new);
keeping the path stable avoids touching deep-link handling, existing route
constants, or any code that already references `/history`, for no
requirement-driven benefit. Recorded explicitly here so it isn't
ambiguous to a future reader why a "Báo cáo" screen lives at `/history`.

## Decision 13: Breakdown sort order — descending by amount spent

**Decision**: The per-item breakdown list is sorted by `spentThisMonth`
descending (highest spender first).

**Rationale**: directly serves spec.md's SC-003 ("identify the single
largest spending item... at a glance") with no interaction required — the
biggest item is always the first row. This is a presentation-ordering
default with no other functional requirement depending on a different
order, low-risk to change later if needed, so it is recorded as a research
decision rather than a separate round of user clarification.

## Decision 14: Section header copy stays "CHI TIÊU THEO KHOẢN"

**Decision**: The breakdown section keeps the source design's Vietnamese
eyebrow text, "CHI TIÊU THEO KHOẢN" ("Spending by item"), as its ARB base
string.

**Rationale**: the wording was always about "khoản" (items) — it remains
accurate under the flat, per-item presentation the spec pivoted to; only
the *content* of each row changed (usage bar vs. share-of-total bar), not
what the section is fundamentally listing. No new header copy is needed.

## Decision 15: `app_router.dart` reaches `ReportScreen` only through `expenses_routes.dart`, never a direct `presentation/` import

**Decision**: `lib/core/router/app_router.dart` does not import
`report_screen.dart` directly. Instead, `expenses_routes.dart` (already
imported by the router, already exposing `overviewRoute`/`spendingRoute`)
gains a third exported builder, `reportRoute(context, state) => const
ReportScreen()`, and the router's `GoRoute` references that instead.

**Rationale**: caught by `test/unit/architecture/architecture_boundary_test.dart`
("core code does not import feature presentation internals") during
implementation — an initial direct `core/router` → `features/expenses/
presentation/report_screen.dart` import violated the same rule
`overviewRoute`/`spendingRoute` already exist specifically to satisfy.
`expenses_routes.dart` is the one file in this feature allowed to import
`presentation/` (it lives inside `features/expenses/` itself); `core/`
only ever imports that thin, already-established indirection. No other
design decision changed — this is a routing-wiring correction only.

## Constitution touch-target reconciliation (44px vs 48dp), resolved by precedent

The source design's month-navigation buttons (`reference/bao-cao-spec.md`)
specify 44×44px circular buttons — below the Constitution's 48×48dp
interactive-touch-target minimum. This is the exact same numeric tension
the Home Overview feature already resolved (its header notification
button): using a stock Flutter `IconButton`, whose default minimum
interactive dimension is 48dp, already satisfies the constitution without
any custom hit-area technique, while the *visual* circle can still render
at the design's 44px. The same resolution applies here, unchanged.
