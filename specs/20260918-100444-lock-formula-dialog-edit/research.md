# Phase 0 Research: Align Expense Control Screen with Design

No `NEEDS CLARIFICATION` markers exist in this plan's Technical Context — the technology stack is fixed by the existing codebase (Flutter/Riverpod/Drift, per the constitution's Recommended Architecture). The unknowns resolved here are implementation-architecture decisions that follow from the spec's requirements but aren't spelled out verbatim in it, discovered while tracing how the existing code (`_ItemFormDialogState.save()`, `ExpenseControlRepository`, `pendingFormulaEditsProvider`) actually behaves today versus what FR-004 now requires.

## 1. The pending-edit map must widen from formula-only to whole-item

**Decision**: Rename `pendingFormulaEditsProvider` (type `Map<String, ExpenseFormulaEdit>`) to `pendingItemEditsProvider`, with a new value type `PendingItemEdit` holding nullable `name`, `iconKey`, `description`, `method`, `value` fields (nullable meaning "unchanged from the committed item," not "changed to null").

**Rationale**: FR-004 requires "Pressing 'Lưu' ... for a leaf item ... MUST stage the name/icon/description AND the formula changes together as a single pending edit for that item." Today's dialog commits name/icon/description immediately via `repository.update()` and only formula changes go through the separate `pendingFormulaEditsProvider` map (populated by inline typing). One item can only have one pending edit at a time (existing behavior, Edge Cases §1) — a second parallel map for metadata would let a leaf have two independent pending states that could disagree about whether an edit exists at all, contradicting FR-008's "the dialog shows the staged value" (singular) and Assumption §1's "reused as-is... only changes *how* entries get added."

**Alternatives considered**:
- *Two separate pending maps (formula + metadata)*: rejected — reintroduces exactly the two-tier state this feature removes (inline formula edits already caused enough resync complexity, per `_FormulaField.didUpdateWidget`'s existing comment about fighting user typing); a single unified pending edit per item is simpler to reason about and matches "a single pending edit" in FR-004's wording.
- *Keep `update()` immediate for metadata, add a second staging mechanism only for formula*: rejected — this is today's actual behavior and is exactly what FR-004 says to stop doing ("stage... together").

## 2. The tree provider's overlay must widen to cover name/icon/description, not just the formula

**Decision**: The provider that assembles `ExpenseControlNode` trees from the raw item stream (which today overlays only pending *formula* values onto matching items) must also overlay pending `name`/`iconKey`/`description` when present, so the list reflects a staged rename/description-change immediately.

**Rationale**: Follows directly from Decision 1 — if the pending map now holds metadata too, the same overlay step that already makes FR-005 ("Staging a formula edit via the dialog MUST immediately update... the inline static value label") true for formula values must also apply to name/icon/description, or a staged rename would be invisible in the list until "Lưu công thức" — silently inconsistent with how the formula half of the same staged edit already behaves.

**Alternatives considered**: *Overlay formula only in the tree, read metadata pending state separately in the dialog only* — rejected: would make the list show a stale name while the dialog (reopened) shows the staged one, violating "single pending edit" coherence and likely surprising in manual testing (the exact kind of on-device inconsistency this feature exists to eliminate).

## 3. Dialog-save routing must branch three ways, not two

**Decision**: `_ItemFormDialogState.save()`'s destination depends on *which* dialog invocation this is:
- **Create** (`existingItem == null`): unchanged — commits directly via `repository.create()`. There is no prior committed state to "stage against" (Assumption §4 already states this explicitly).
- **Edit, group** (`existingItem != null`, `isFormulaEditable == false`): unchanged — commits directly via `repository.update()`, name/icon/description only, exactly as today (FR-003: "the dialog MUST continue to show only name/icon/description, unchanged from today").
- **Edit, leaf** (`existingItem != null`, `isFormulaEditable == true`): **new** — writes into `pendingItemEditsProvider` instead of calling `repository.update()`. Only "Lưu công thức" (or the tab-switch prompt's "Lưu" choice) later calls `repository.update()` / `saveFormulas()`.

**Rationale**: The spec draws this exact line — FR-003 explicitly preserves current group behavior, while FR-004 explicitly changes leaf behavior. `isFormulaEditable` (already threaded through `ExpenseControlFormParams`) is the existing signal that already distinguishes these two dialog shapes, so no new flag is needed — only the leaf branch's save destination changes.

**Alternatives considered**: *Stage groups too, for consistency* — rejected: out of scope (FR-003 is explicit that group dialog behavior is unchanged) and would stage a save with nothing to validate against (groups have no formula, so there is no over-budget check to defer), adding complexity with no corresponding requirement.

## 4. "Lưu công thức" becomes the sole commit path for staged leaf metadata too — same button, no rename

**Decision**: After Decision 3, pressing "Lưu công thức" with a pending edit that only changed a leaf's name (no formula change) still commits that name change (via the same `saveFormulas`-adjacent write this button already triggers, now also flushing metadata for pending items). The button's Vietnamese label and its "only visible/enabled when something is pending" gating (FR-007) are unchanged — "something pending" now means "any field of a `PendingItemEdit`," not narrowly "a formula."

**Rationale**: The user's own framing of this feature ("nút edit sẽ là edit luôn cả toàn bộ giá trị của khoản đó về mặt config, tạm lưu và effect khi save. Khi nào lưu công thức thì mới lưu chính thức") explicitly describes the whole item's config as staged-then-committed by the same one button, not a new second button. Introducing a differently-labeled commit action for "just metadata" pending edits would contradict that and complicate FR-009's tab-switch guard (which would then need to distinguish two kinds of pending state).

**Alternatives considered**: *Rename the button to something formula-agnostic (e.g., "Lưu thay đổi")* — considered but explicitly deferred: it's a copy-only change with no functional dependency on this feature's other decisions, so bundling it here would be scope creep beyond what was requested; noted here only so a future pass doesn't rediscover the same tension.

## 5. FR-009's "formula edit is staged" wording now means "any pending item edit"

**Decision**: FR-009's navigation-confirmation trigger condition ("at least one formula edit is staged") is understood, post-Decision 1, as "at least one pending item edit exists" (i.e., `pendingItemEditsProvider` is non-empty) — not narrowly formula-only.

**Rationale**: Follows mechanically from Decision 1's map rename; called out explicitly here (rather than left implicit) because FR-009 through FR-012's prose still says "formula edit" verbatim and a future reader implementing strictly from that wording alone could miss that a staged rename-with-no-formula-change also must trigger the tab-switch guard, per Decision 4's "any field" framing.

**Alternatives considered**: *Leave FR-009 formula-only, add a second separate guard for metadata-only pending edits* — rejected as an unnecessary second code path for a scenario (staged rename, no formula change) that Decision 1 already unifies into one pending-edit concept.

## 6. Existing tests with assertions that contradict the new leaf-dialog-save behavior are expected regressions, to be updated in this PR

**Decision**: The following existing tests currently assert the *old* immediate-commit behavior for a leaf's edit dialog and MUST be updated (not merely left failing) as part of implementing this feature, per the constitution's Testing Standards principle ("Tests MUST be written or updated in the same pull request as the behavior they cover"):
- `test/widget/features/expense_control/expense_control_screen_test.dart` — `"editing name/icon/description via the pencil dialog persists immediately (US3 Scenario 1)"`: this test's own name states the now-obsolete behavior; it must be rewritten to assert stage-then-"Lưu công thức"-commits instead of immediate persistence, for the leaf case specifically (the equivalent group-dialog test, if any, is unaffected — see Decision 3).
- `test/unit/features/expense_control/expense_control_form_controller_test.dart` — any assertion that `save()` calls `repository.update()` synchronously for an existing *leaf* item must invert to assert `repository.update()` is **not** called until a separate "Lưu công thức" action, while the equivalent group-item assertion is unchanged.

**Rationale**: These are not accidental breakage — they are the automated-test expression of the exact behavior FR-004 requires changing. Flagging them here (rather than discovering them only when `flutter test` fails during implementation) keeps the Constitution Check's Principle II obligation ("MUST be updated in the same pull request") an explicit, planned task rather than a surprise.

**Alternatives considered**: *Leave old tests as-is and let them fail, fix opportunistically* — rejected outright: the constitution treats a failing test suite as blocking merge; these updates are scoped work items, not follow-up cleanup.
