# Research: Expense Control

**Input**: `spec.md`, `.specify/memory/constitution.md`, existing `lib/features/envelopes/**` and `lib/core/**` (this feature refactors/replaces the Envelope feature per Clarifications).

No `NEEDS CLARIFICATION` markers remain in the Technical Context — the existing codebase already fixes the stack (Flutter + Riverpod + Drift + go_router + lucide_icons + bundled Lexend font), so this research focuses on integration decisions rather than technology selection.

## 1. Data model shape: single self-referencing table vs. separate Group/Item tables

**Decision**: One Drift table, `ExpenseControlItems`, with a nullable `parentId` self-reference (adjacency list). A row with `parentId == null` is top-level; a row with `parentId` set is a child. Nesting is capped at one level in the domain layer (a row whose own id is used as someone's `parentId` cannot itself have a non-null `parentId`) — not by a DB constraint, matching how `envelopes_table.dart` also leaves cross-row invariants (e.g. single rounding-receiver) to the repository/domain layer rather than SQL constraints.

**Rationale**: Groups and leaf items share every field (name, icon, description, sort order) and only differ in whether they carry a formula and whether `parentId` is null. A single table avoids duplicating columns across two tables and avoids a join for the common "flatten to compute totals" operation (FR-007/FR-008 need to sum percentages across every leaf in the whole plan, regardless of nesting).

**Alternatives considered**: Separate `ExpenseControlGroups` + `ExpenseControlItems` tables — rejected: doubles CRUD/repository surface for two things that are 90% structurally identical, and the leaf⇄group transition (FR-004/FR-005) would require moving a row between tables instead of just nulling/setting two columns.

## 2. Icon selection: predefined set vs. free picker

**Decision**: Reuse the project's existing single icon library (`lucide_icons`, already a dependency and already used for nav/header icons per `reference/icons.json`). Define a fixed, curated `const Map<String, IconData>` (icon key → `IconData`) in the feature's presentation layer; the icon picker (FR-001) lets the user choose from this fixed set. Persist the **key** (a stable string, e.g. `"home"`), never the `IconData` itself.

**Rationale**: Constitution's Recommended Architecture implies one consistent icon system app-wide; introducing a second icon source (asset SVGs, another package) for this feature only would fragment it. Persisting a stable string key (not a raw codepoint) keeps the stored value renderer-agnostic and safe across icon-package version bumps.

**Alternatives considered**: Store the raw `IconData.codePoint`/`fontFamily` — rejected, brittle across package upgrades and unreadable in stored payloads/outbox JSON.

## 3. Existing "Khoản" (Envelope) data: how "discarded, not migrated" is actually implemented

**Decision**: Bump `AppDatabase.schemaVersion` from 1 to 2. Add the new `ExpenseControlItems` table. `AppDatabase.migration` currently only defines `beforeOpen` (no `onUpgrade`) — add an `onUpgrade` step (`from == 1`) to `MigrationStrategy` that soft-deletes every existing `Envelopes` row (`deletedAt = now()` where currently null) — no new table is introduced for envelopes, no data is copied into `ExpenseControlItems`. Fresh installs never run this step (they get schema version 2 directly via `onCreate`), so it's purely an upgrade-path cleanup for the test-only data already on developer/tester devices.

**Rationale**: The spec (FR-019, and User Story 4 scenario 4) requires that the renamed "Thu chi"/"Hồ sơ" screens — which still run on the old Envelope-based logic — show their *empty* state after this feature ships, not stale envelope rows. Soft-deleting (not hard-deleting) is consistent with the existing tombstone pattern (`deletedAt`) used everywhere else, and is trivially reversible if ever needed. The `Envelopes` and `EnvelopeCoverages` tables themselves are **not** dropped — `Spending`/`Overview` still query them (per Assumptions, rewiring those screens is out of scope), so removing the tables would break compilation of code this feature explicitly does not touch.

**Alternatives considered**: Hard-delete envelope rows — rejected, inconsistent with the app's offline-first soft-delete/outbox pattern and irreversible. Leaving old envelope rows untouched — rejected, contradicts FR-019/User Story 4 Scenario 4's explicit "now shows empty states" requirement.

## 4. Reordering scope: top-level only vs. children too

**Decision**: Drag-and-drop reorder (FR-014) applies only to top-level items/groups, exactly as scoped. Children within a group are not reorderable in this feature; a new child is always appended at the end (FR-004 acceptance scenario 4).

**Rationale**: Confirmed directly against the mockup (`reference/kiem-soat-spec.md`): the `grip-vertical` drag handle icon appears only in the group-header row, never on a child-item row. No clarification needed — the visual source of truth already resolves this.

## 5. Business-rule placement: where FR-003/004/005/007/008/012 live

**Decision**: A pure-Dart domain service (no Flutter/Drift imports) owns:
- Building the tree (top-level items + their children) from the repository's flat `watchAll()` stream.
- Computing running totals (percent allocated, fixed-item count, percent free) across every leaf in the tree — FR-011.
- Validating a candidate create/edit against FR-007 (≤100%) and FR-008 (strictly <100% when any fixed item exists anywhere in the plan) *before* the presentation layer calls the repository — FR-012 (save is blocked client-side, never persisted invalid).
- Deciding the leaf⇄group transition: adding a first child clears the parent's formula (FR-004); removing the last child makes the parent formula-eligible again (FR-005) — the *value* is left unset (not auto-restored), matching FR-005's "becomes eligible to be given its own formula again," not "regains its previous formula."

**Rationale**: Matches Constitution Principle I (business logic MUST NOT live in `build()`/widgets) and Principle II (domain logic must be unit-testable at ≥80% coverage without a Flutter test harness). The repository (`data/` layer) stays CRUD-only plus the one cross-record side effect that mirrors the existing `EnvelopeRepositoryImpl._clearExistingReceiver` precedent: clearing a parent's formula fields when its first child is inserted happens inside the repository's child-create transaction (same transaction as the insert + outbox rows), not as a separate round trip.

**Alternatives considered**: Enforcing the percentage-sum rule as a DB trigger/check — rejected, Drift/SQLite constraints can't easily express "sum across a dynamic set of sibling rows conditioned on whether any fixed-mode row exists," and it would bypass the "block before persisting" UX requirement (FR-012), which needs to run synchronously against in-memory form state as the user types.

### 5b. Allocation-mode enum: reuse vs. redeclare

**Decision**: Declare a new, feature-local `enum ExpenseAllocationMethod { percentage, fixed }` inside `expense_control_items_table.dart`, rather than importing `envelopes_table.dart`'s existing `enum AllocationMethod { percentage, fixed }`.

**Rationale**: The two enums are structurally identical today, but importing a table file from one feature's table file into another's is a cross-feature coupling the Constitution's feature-first module rule doesn't intend for `core/database/tables/` (features must not depend on each other's internals). It also decouples the two schemas going forward — `Envelopes` is legacy/frozen (per Assumptions, out of scope), so it must not gain or lose values because `ExpenseControlItems` needs a new one later.

## 6. Empty state widget (Clarifications: first-run empty state)

**Decision**: Introduce one small reusable widget, `core/widgets/empty_state_view.dart` (icon + message + optional CTA button), and use it for this feature's FR-023 empty state. Do not refactor the existing ad hoc `Center(child: Text(...))` empty states in `envelopes_screen.dart`/`spending_screen.dart`/`overview_screen.dart` to use it — out of scope for this feature.

**Rationale**: Constitution Principle III requires empty states to "follow the same reusable patterns across the app" and forbids a new screen inventing a bespoke pattern where an existing one applies. No existing shared empty-state widget currently exists (each screen inlines its own `Center`+`Text`), and none of those existing ones need a CTA button, so there's no existing reusable pattern this feature can reuse as-is. Placing the new widget in `core/widgets/` (rather than feature-local) makes it available to a second consumer without a later relocation, satisfying the "belongs in `core/` only if used by two or more features" rule the moment a second screen adopts it, while costing nothing extra now.

**Alternatives considered**: Feature-local empty-state widget under `features/expense_control/presentation/widgets/` — rejected, would need to move to `core/` anyway per the constitution's own stated rule the first time another screen wants the same CTA pattern, and the widget has zero feature-specific logic today.

## 7. l10n key strategy for renamed tabs

**Decision**: Keep the existing ARB keys `tabSpending` and `tabAccount` (they identify *screens*, not literal label text); only change their **string values** — `tabSpending`: "Chi tiêu" → "Thu chi" (vi), "Spending" stays as-is or is reviewed for the `en` equivalent; `tabAccount`: "Cá nhân" → "Hồ sơ" (vi). Add two new keys: `tabExpenseControl` (replaces `tabEnvelopes`'s nav slot) and `tabHistory` (new placeholder tab).

**Rationale**: Renaming the ARB keys themselves would touch every reference to `l10n.tabSpending`/`l10n.tabAccount` in `app_router.dart` for no functional benefit — the key is an internal identifier, the constitution's localization requirement is about user-facing *string values* having both `vi`/`en` translations, not about key-naming.

## 8. Placeholder screen for "Lịch sử/Báo cáo"

**Decision**: A minimal `HistoryPlaceholderScreen` widget (feature: `features/history/presentation/`) — reuses the new `EmptyStateView` (§6) with a "coming soon"-style message, no data layer, no provider.

**Rationale**: Spec explicitly scopes this tab's real content out (Assumptions); it only needs to exist so the 5-tab navigation (FR-020) is complete and User Story 4 Scenario 3 is satisfiable.

## 9. "Lưu công thức" scope and interaction model (resolves `/speckit-analyze` finding G1)

`/speckit-analyze` flagged that FR-012 names a specific action ("the 'Lưu công thức' action"), the mockup (`reference/kiem-soat-spec.md`) shows it as exactly one button at the bottom of the whole screen (sibling to the group list and the summary banner, not nested inside any per-item dialog), and the Edge Case "navigates away without tapping 'Lưu công thức' → unsaved changes discarded" implies staged, discardable edits — none of which was reflected in any task.

**Decision**: "Lưu công thức" ("Save **formula**" — the literal name scopes it to `allocationMethod`/`allocationValue` specifically, not the whole item) governs only **inline formula edits to already-existing items**, which is a User Story 3 concern ("adjusting its formula," US3's own framing):

- **Structural CRUD stays immediate**, exactly as already designed: creating an item (US1, via the "Thêm khoản mới" dialog, including that new item's *initial* formula — required up front by FR-017) persists immediately on the dialog's own confirm; renaming/re-iconing/re-describing an existing item (US3, via the pencil dialog) persists immediately on that dialog's confirm; deleting a leaf or group (US3) is immediate, matching spec.md US3 Acceptance Scenario 4's explicit "removed **immediately**"; reordering (US3) persists immediately on drop.
- **Only the formula value/mode of an *existing* item, edited inline in its row** (the always-visible value field + %/₫ toggle shown in every leaf/child row per the mockup — distinct from the pencil-dialog's name/icon/description fields), is staged in a screen-scoped, `autoDispose` Riverpod provider (`Map<String, ExpenseFormulaEdit>`, keyed by item id — data-model.md) rather than written to the repository on every keystroke.
- `ExpenseControlPlanService`'s tree/totals/validation functions accept this pending-edit map as an optional overlay, so the summary banner (FR-011 "updates live as the user edits") reflects uncommitted inline changes immediately, and FR-012's block-before-persist check runs against the *merged* (persisted + pending) state.
- Tapping "Lưu công thức" validates the merged state; if valid, calls the repository's new `saveFormulas` (batch transaction, one outbox row per changed item — contracts/expense_control_repository.md) and clears the pending-edit provider; if invalid, stays blocked and flags the violating total (FR-012), exactly like the create/edit dialogs already do for their own scope.
- **Discard trigger**: `app_router.dart`'s bottom nav is a `StatefulShellRoute.indexedStack`, which keeps every branch's widget tree (and therefore plain `autoDispose` Riverpod state) alive across tab switches — a naive `autoDispose` provider would NOT be disposed by switching tabs and back, only by a full app kill, which understates the Edge Case ("navigates away" plainly means leaving the tab, not killing the process). Instead, `_AppShell` (`app_router.dart`) explicitly watches `navigationShell.currentIndex`; when it changes away from the Kiểm soát branch's index, it calls `ref.invalidate()` on the pending-formula-edits provider. The provider is still declared `autoDispose` (belt-and-braces for the full-app-kill case), but the *primary* discard mechanism is this explicit index-change listener, not disposal.

**Rationale**: This is the only reading consistent with *all* the evidence at once: the mockup's single page-level button, FR-012's literal wording ("formula," not "item" or "changes"), the Edge Case's "unsaved changes discarded" framing (which only makes sense for something genuinely un-persisted), and US3 Acceptance Scenario 4's explicit "removed immediately" for deletion (which rules out a whole-plan-is-staged model). It also avoids inventing a novel batch-save UX pattern for structural CRUD, which would conflict with Constitution Principle III's "a new screen MUST NOT invent a bespoke pattern where an existing one applies" — every other screen in this app (including `envelopes_form_screen.dart`) persists CRUD immediately; only the plan-wide percentage math genuinely benefits from a review-then-commit step, since FR-007/FR-008 are inherently whole-plan checks that would be jarring to enforce on every keystroke of a single field.

**Alternatives considered**: Whole-plan staging (every CRUD action staged, one global commit) — rejected, contradicts US3 Scenario 4's "removed immediately" and would be a bespoke pattern unlike anything else in the app. Per-item "Lưu công thức" buttons (one per row) instead of one page-level button — rejected, contradicts the mockup's explicit single page-bottom button placement.

## 10. Currency/percentage formatting (resolves `/speckit-analyze` finding C1)

**Decision**: `AllocationSummaryBanner` and `ExpenseItemRow` MUST format fixed-amount VND values through the existing `lib/core/formatting/currency_formatter.dart` (already used elsewhere in the app) rather than ad hoc string interpolation, per Constitution Principle III's shared-formatting-utility requirement. Percentage values use a single local helper (e.g. `'${value.toStringAsFixed(0)}%'` centralized in one place within the feature, not repeated per widget) for consistency across the banner and every row.

## 11. Accessibility for icon-only controls (resolves `/speckit-analyze` finding C2)

**Decision**: Every icon-only custom control introduced by this feature — the group-card drag handle, pencil/trash buttons, chevron, %/₫ toggle chips, and the icon picker's selectable icons — gets a `Semantics` label (or, where a plain `IconButton`/`Tooltip` already provides one, an explicit `tooltip:`), per Constitution Principle III ("MUST be reachable via screen readers"). Labels are ARB-sourced strings like `reorderGroupHandle`, `editItemButton`, `deleteItemButton`, matching the bilingual requirement (FR-021).

## 12. Bottom navigation cleanup (resolves `/speckit-analyze` finding I1)

**Decision**: FR-020 states Kiểm soát *replaces* the old "Khoản" tab and that the navigation must show *exactly* 5 tabs. The existing `/envelopes` `StatefulShellBranch`, its `NavigationDestination` (`l10n.tabEnvelopes`), and the now-orphaned `EnvelopesScreen`/`EnvelopeFormScreen`/`envelopes_providers.dart` are removed as part of this feature (not left as unrouted dead code, per Constitution Principle I) once the Kiểm soát tab is in place. The `tabEnvelopes` ARB key is removed from both `app_vi.arb`/`app_en.arb`. `Envelope`/`EnvelopeRepository`/the `envelopes`+`envelope_coverages` Drift tables themselves are **not** removed — per Assumptions, `Spending`("Thu chi")/`Overview` still read through `AllocationRepository`/envelope-adjacent data for their (now-empty, per FR-019) existing logic; only the dedicated CRUD *screen* for envelopes is retired, since Kiểm soát supersedes its purpose. This cascades one level further: `envelope_form_controller.dart` is imported only by `envelope_form_screen.dart` (verified), so it becomes dead code the moment that screen is deleted and MUST be deleted alongside it; `test/widget/features/envelopes/envelopes_screen_test.dart` tests the deleted `EnvelopesScreen` class directly and MUST be deleted too, or it breaks compilation (Constitution Principle I's zero-errors gate) rather than merely leaving dead code.
