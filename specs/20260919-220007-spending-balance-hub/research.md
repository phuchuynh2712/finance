# Phase 0 Research: Spending Balance Hub & Envelope Retirement ("Thu chi")

## Decision 1: `balance` lives on `ExpenseControlItem`, not a new table/entity

**Decision**: Add a single `balance` column (integer, VND minor-unit-free like `ExpenseEntries.amount`/`Envelopes.balance` already are) directly to the existing `ExpenseControlItems` Drift table and the `ExpenseControlItem` domain entity. No new table, no new feature module for "balance."

**Rationale**: spec.md's Assumptions section is explicit that "Thu chi" displays the *same* Kiểm soát chi tiêu tree, not a parallel hierarchy. `ExpenseControlItem` (`lib/features/expense_control/domain/expense_control_item.dart:12-73`) is already the single source of truth for every group/leaf a user has configured; adding a field there means `SpendingScreen` can reuse `ExpenseControlPlanService.buildTree()` (`expense_control_plan_service.dart:83-109`) verbatim for tree assembly instead of re-implementing group/child grouping. A separate `ExpenseControlBalances` table keyed by `expenseControlItemId` was considered and rejected: it would require a join on every read for no benefit, since balance is a 1:1, always-present attribute of a leaf item (never optional, never many-per-item).

**Alternatives considered**:
- Separate `ItemBalances` table (1:1 with `ExpenseControlItems`): rejected — adds a join with no cardinality or lifecycle benefit; a `balance` column is exactly as normalized here since it's a mandatory scalar attribute, not a variable-cardinality relationship.
- Migrating `Envelope.balance` values into the new column: rejected per explicit user decision (spec.md Clarifications) — `Envelope` is deleted outright, not migrated from; every leaf item starts at 0 regardless of what any pre-existing `Envelope` row held.

## Decision 2: Group balance is computed live (sum of children), never stored

**Decision**: Only *leaf* items (`allocationMethod`/`allocationValue` non-null, no children) get a real `balance` column value. A group's displayed balance is `sum(children.balance)`, computed at read time in `ExpenseControlPlanService` (a new method alongside `computeTotals`), exactly mirroring how that service already computes a group's aggregate percentage from its children (`computeTotals`, plan_service.dart:114-136).

**Rationale**: Confirmed directly with the user during `/speckit-clarify` (spec.md Clarifications). Storing a redundant group-level balance would require keeping it in sync on every child balance change (a write-fan-out problem with no upside), whereas summing at read time is O(children) — negligible at this app's scale — and can never drift out of sync with its children, which a stored+synced value could.

**Alternatives considered**:
- Storing a denormalized group balance, updated by a trigger/transaction whenever a child's balance changes: rejected — adds write complexity and a consistency-bug surface for a value that's cheap to compute on read and is only ever *read* in this feature (nothing here writes balances at all).

## Decision 3: `balance` defaults to 0, and the Envelope-era tables are dropped, in a single schema v2→v3 migration step

**Decision**: Bump `AppDatabase.schemaVersion` from 2 to 3 (`lib/core/database/app_database.dart:33`) and add ONE `onUpgrade` step (`from == 2`) that, in the same transaction: (a) adds `ExpenseControlItems.balance` with `DEFAULT 0`, then (b) drops `EnvelopeCoverages`, `AllocationEventLines`, `AllocationEvents`, `ExpenseEntries`, and finally `Envelopes` — in that order, since SQLite enforces `PRAGMA foreign_keys = ON` (`app_database.dart:52`) and each table in that list is referenced by the one(s) before it. A matching Supabase migration performs the equivalent `ALTER TABLE`/`DROP VIEW`/`DROP TABLE` sequence for the remote schema.

**Rationale**: A single version bump handles both changes atomically — there is no reason to spread "add a column" and "drop four tables" across two separate schema versions (e.g. v3 then v4), since Drift migrations run arbitrary code inside `onUpgrade` and both changes are part of the same feature's rollout. Combining them also means a user upgrading directly from v2 never passes through an intermediate state where `balance` exists but Envelope hasn't been cleaned up yet (or vice versa). The drop order matters and is fixed by FK dependency, not by convenience: `EnvelopeCoverages`/`AllocationEventLines`/`ExpenseEntries` each reference `Envelopes` directly (or, for `AllocationEventLines`, transitively via `AllocationEvents`' own row), so all four dependents must go before `Envelopes` itself.

**Alternatives considered**:
- Two separate migration steps (v2→v3 for `balance`, v3→v4 for dropping Envelope): rejected — adds an intermediate schema state with no user-facing or testing benefit, and doubles the number of migration paths that need testing (fresh install, v1→v2→v3→v4, v2→v3→v4) for no gain.
- A one-time Dart script that inserts balance rows instead of a column default: rejected — unnecessary since a column default handles every case (new inserts and pre-existing rows) atomically as part of the schema migration itself.
- Soft-deleting Envelope's tables (matching the `deletedAt` pattern used when Envelope was first retired, `app_database.dart:38-49`) instead of dropping them: rejected — that soft-delete already happened once (schema v1→v2) precisely to preserve the *option* of a later hard delete; this feature is that later hard delete the user explicitly asked for ("Bạn định khi nào sẽ xóa Envelope?"), so a second, permanent soft-delete would just delay the actual cleanup indefinitely.

## Decision 4: The "not yet available" placeholder generalizes the existing `HistoryPlaceholderScreen`, reused across FOUR entry points (not three)

**Decision**: Move and generalize `lib/features/history/presentation/history_placeholder_screen.dart`'s widget into `lib/core/widgets/not_available_placeholder_screen.dart`, accepting `icon`/`title`/`message` as constructor parameters instead of hardcoding the history tab's own l10n strings. It now has FOUR call sites, not three: `SpendingScreen`'s "Thu nhập"/"Chi tiêu"/"Xem lịch sử giao dịch" (each via `Navigator.push` to a `MaterialPageRoute`, giving each a distinct `AppBar`/back button automatically) PLUS the "Báo cáo" tab's existing usage PLUS (added after the scope expansion to retire Envelope) `OverviewScreen`'s entire replacement content, rendered in-place as this same widget rather than pushed (since "Tổng quan" is itself a bottom-nav tab, not something navigated *to* from another screen).

**Rationale**: `HistoryPlaceholderScreen` (`lib/features/history/presentation/history_placeholder_screen.dart:9-23`) is already exactly the shape needed — `Scaffold` + `AppBar(title)` + the shared `EmptyStateView` (`lib/core/widgets/empty_state_view.dart:8-46`, already icon/message-parameterized) — it just currently hardcodes strings instead of accepting them as constructor parameters. Moving it to `lib/core/widgets/` (rather than leaving it in `lib/features/history/`) reflects that it's now used by two entirely different features' tabs plus three sub-navigation entry points — a shared, feature-agnostic widget belongs in `core/`, not owned by the one feature (`history`) that happened to write it first.

**Alternatives considered**:
- Four separate placeholder screen classes: rejected — pure duplication of a screen that's already fully generic in shape; would also mean four near-identical widget tests instead of one shared one plus four thin call-site assertions.
- A `showDialog`/`SnackBar` instead of a pushed screen for the three `SpendingScreen` entry points: rejected — explicitly ruled out by the `/speckit-clarify` answer confirming a dedicated screen with a back action, matching the `HistoryPlaceholderScreen` pattern.
- Leaving `OverviewScreen` as its own distinct (if now-empty) widget rather than directly rendering the shared placeholder: rejected — there is nothing left for `OverviewScreen` to do once its `Envelope` dependency and FAB are removed (spec.md Clarifications: "Tổng quan" has no content worth preserving), so a thin wrapper would add an extra indirection with no behavior of its own.

## Decision 5: Bottom navigation bar — remove the pill via `indicatorColor: transparent` plus explicit icon/label color states

**Decision**: In `lib/core/theme/app_theme.dart`'s `NavigationBarThemeData` (currently only setting `indicatorColor: AppColors.lightPrimary`/`AppColors.darkPrimary` at lines 37-39/56-58), set `indicatorColor: Colors.transparent` and add `iconTheme` and `labelTextStyle` as `WidgetStateProperty.resolveWith` (or `.fromMap`) values that return the brand primary blue when `WidgetState.selected` is present and the existing muted/inactive color (`AppColors.lightFg3`/`AppColors.darkFg3`) otherwise.

**Rationale**: Per the research done ahead of this plan (matching Flutter's `NavigationBar` Material 3 behavior): the widget always paints an indicator shape behind the selected icon — making it fully transparent removes its visible pill/chip, but doing that *alone* leaves icon/label color selection to Material 3's defaults, which are not guaranteed to read as "brand blue when selected." Both properties must be set together to reproduce the design's actual intent (icon+label change color; no shape) rather than accidentally ending up with a fully invisible selection state.

**Alternatives considered**:
- Keeping the indicator but shrinking/restyling it: rejected — the design mockups (`reference/screen-light.png`, `reference/screen-dark.png`) and `reference/thu-chi-spec.md:50` show no background shape at all behind the active tab's icon, only a color change.
- Replacing `NavigationBar` with a fully custom bottom-bar widget: rejected as unnecessarily large a change for a color/indicator fix — `NavigationBarThemeData` already supports the exact effect needed without abandoning the shared Material widget.

## Decision 6: Dark-mode active icon color — introduce `AppColors.darkPrimaryAccentText` (`#6AADFF`)

**Decision**: Add a new `AppColors.darkPrimaryAccentText = Color(0xFF6AADFF)` constant (matching `theme-tokens.json`'s dark `primaryAccentText` token, `reference/theme-tokens.json:65`) and use it — not `AppColors.darkPrimary` (`#3B8DF8`) — as the selected-state icon/label color in dark mode's `NavigationBarThemeData`. Light mode continues to use the existing `AppColors.lightPrimary` (`#1A72E0`), which already matches the design's light-mode `blue-600`.

**Rationale**: The design package's `icons.json` (`reference/icons.json:13-16`) and `thu-chi-spec.md:50` specify the bottom nav's active icon/label color in dark mode as `#6AADFF`, a lighter, higher-contrast-on-dark-background accent distinct from the base `primary` (`#3B8DF8`) used for buttons/indicators elsewhere. This app's dark theme already has this exact concept for other UI (`AppColors.darkPrimary` vs. what the design calls `primaryAccentText`) but had not yet needed a named constant for it since no prior feature's dark-mode text/icon used it directly — this feature is the first to need it, so it's added rather than reusing `darkPrimary` and producing a duplicate-but-different color from the mockup's precise reading.

**Alternatives considered**:
- Reusing `AppColors.darkPrimary` for the dark-mode active nav icon: rejected — it doesn't match the design token pixel-for-pixel (`#3B8DF8` vs. the mockup's `#6AADFF`), and this session's own screenshot evidence (`reference/screen-dark.png`) shows a visibly lighter blue than the plain `primary` swatch used elsewhere in dark mode.

## Decision 7: `ExpenseEntry`/`ExpenseFormScreen`/`ExpenseFormController` are deleted outright, not adapted to point at `ExpenseControlItem`

**Decision**: Delete `lib/features/expenses/domain/expense_entry.dart`, `expense_repository.dart`, `envelope_coverage.dart`, `compute_overspend.dart`, `lib/features/expenses/data/expense_repository_impl.dart`, `lib/features/expenses/presentation/expenses_providers.dart`, `expense_form_screen.dart`, `expense_form_controller.dart`, and their test files entirely. Do not change `ExpenseEntry.envelopeId` to `expenseControlItemId` and keep the rest of the class/UI working.

**Rationale**: Confirmed directly with the user (spec.md Clarifications). The old form's entire UX (a flat envelope-picker dropdown, an overspend-detection dialog offering to pick a *covering* envelope) is built around Envelope's flat, no-hierarchy shape and a borrowing mechanic the user explicitly chose to drop (Decision 8 below) — there is nothing left of that UX that would still make sense unmodified against `ExpenseControlItem`'s tree. Editing the FK type alone would leave a screen whose *behavior* (dropdown of all items including groups it shouldn't allow picking, an overspend dialog offering a "covering" concept the app no longer has) is subtly wrong in ways worse than not having the screen at all. A future feature builds the real replacement once it can design the picker/overspend UX against the tree shape properly.

**Alternatives considered**:
- Renaming the FK and mechanically fixing compile errors, keeping the rest of the form: rejected — produces a screen with `Envelope`-shaped UX (flat dropdown, "covering" dialog) sitting on `ExpenseControlItem`-shaped data, which is more confusing than an honest "not yet available" placeholder (User Story 3 already provides exactly that for "Chi tiêu").

## Decision 8: "Covering" and "rounding receiver" mechanics are dropped, not redesigned, in this feature

**Decision**: No equivalent to `EnvelopeCoverage` (borrowing from another item when one goes negative) or `Envelope.isRoundingReceiver` (the one item that absorbs a percentage split's rounding remainder) is added to `ExpenseControlItem` or anywhere else in this feature. An item is simply allowed to hold a negative `balance`, displayed as-is (FR-004).

**Rationale**: Confirmed directly with the user (spec.md Clarifications) — both mechanics are real, working features of `Envelope` (`expense_repository_impl.dart`'s `_applyExpenseEffects`/`_reverseExpenseEffects`, `compute_allocation_preview.dart`'s rounding-remainder handling), but porting them properly requires designing how "borrowing" and "who receives the rounding remainder" work against a *tree* (group/children) instead of a flat list — a nontrivial design question (e.g., can a leaf borrow from its own sibling? From anywhere in the tree? Does a group need its own rounding-receiver concept, or only leaves?) that has no obvious answer yet and isn't needed until a future feature actually implements income allocation or expense recording against `ExpenseControlItem`. Building it speculatively now, before that future feature's real requirements are known, risks guessing wrong and having to redesign it anyway.

**Alternatives considered**:
- Porting both mechanics as flat concepts (ignore the tree, treat every leaf as if it were still a flat list) now, to preserve some feature parity: rejected — this was directly asked about and the user chose to defer instead, since a flat-list port would likely need to be redone anyway once a future feature actually needs to think about "borrowing across groups" or "rounding within vs. across a group."

## Decision 9: The Supabase migration matches the local Drift migration's exact drop order, and the sync worker's Envelope-reconciliation path is deleted (not stubbed)

**Decision**: The new Supabase migration (a) runs `ALTER TABLE expense_control_items ADD COLUMN balance integer NOT NULL DEFAULT 0;`, then (b) `DROP VIEW envelope_balances;`, then (c) drops `envelope_coverages`, `allocation_event_lines`, `allocation_events`, `expense_entries`, `envelopes` in that order (data-model.md). `lib/core/sync/sync_worker.dart`'s `_reconcileBalances()` method (currently calling `_client.from('envelope_balances')`, per the exploratory research behind this plan) has its Envelope-specific reconciliation logic deleted outright — not replaced with a no-op stub, not left calling a now-nonexistent view.

**Rationale**: The view must be dropped before any table it selects from (Postgres enforces this), matching the same dependency ordering as the local Drift drop (Decision 3). Deleting `_reconcileBalances()`'s Envelope logic outright (rather than a silent no-op) was the user's explicit choice (spec.md Clarifications) — leaving dead code that constructs a request to a deleted endpoint, even if wrapped to swallow the resulting error, is exactly the kind of orphaned-but-technically-still-there code this whole feature exists to eliminate. If reconciliation for `ExpenseControlItem.balance` is needed later, a future feature designs it fresh against that table, per spec.md Assumptions.

**Alternatives considered**:
- Leaving `_reconcileBalances()` in place but wrapped in a try/catch that silently ignores the now-404ing Supabase call: rejected — this is exactly the "orphaned, untestable-by-neglect" pattern User Story 5's own rationale calls out as the reason to do this cleanup properly instead of leaving a disconnected system half-alive.

## Decision 10: Orphaned ARB strings are identified by grep-for-zero-references, not by manual inspection

**Decision**: After deleting all Envelope/ExpenseEntry-era Dart files, find every ARB key in `app_vi.arb`/`app_en.arb` whose generated `AppLocalizations` getter (e.g. `l10n.envelopeFormTitleCreate`) has zero remaining references anywhere under `lib/`, and delete those key pairs from both files. This is expected to catch keys already identified as suspicious during research (e.g. `envelopeFormTitleCreate`, `envelopeReassignReceiverTitle`) that appear to predate even this feature's deletions — they were already unreferenced by any existing `.dart` file before this feature started.

**Rationale**: A grep-for-zero-references pass is exhaustive and mechanical — it won't miss a stale key the way manually eyeballing ~60+ Envelope-related ARB entries (research.md's exploratory count) would, and it naturally also catches any *pre-existing* dead strings unrelated to this feature's own deletions, satisfying FR-021's "no dead/unreferenced translation keys remain" without needing a separate cleanup pass for those older orphans.

**Alternatives considered**:
- Only removing ARB keys for the exact screens this feature deletes, leaving already-orphaned pre-existing keys alone: rejected — FR-021 doesn't scope the requirement to "keys orphaned by this feature specifically," and leaving known-dead strings in place after noticing them during this feature's own research would be an intentional half-measure.
