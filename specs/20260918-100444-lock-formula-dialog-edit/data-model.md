# Phase 1 Data Model: Align Expense Control Screen with Design

No database schema changes. No new persisted entity. This feature only changes the shape of one **in-memory, presentation-layer** type (research.md Decision 1) and how existing entities are read/written around it.

## Expense Control Item (leaf) — unchanged

`lib/features/expense_control/domain/expense_control_item.dart`'s `ExpenseControlItem` is unchanged by this feature: same fields, same `copyWith`/`clearFormula`. What changes is *when* `allocationMethod`/`allocationValue` get written (research.md Decision 3: via the pending-edit flow for an existing leaf, never directly from the edit dialog's `save()` anymore) — a call-site change, not a shape change.

| Field | Type | Notes |
|---|---|---|
| `id` | `String` | Unchanged |
| `userId` | `String` | Unchanged |
| `parentId` | `String?` | Unchanged — `null` = top-level |
| `name` | `String` | Unchanged shape; now only ever committed for a leaf via the staged-edit flow (never directly from the dialog) |
| `iconKey` | `String` | Same as `name` |
| `description` | `String?` | Same as `name` |
| `sortOrder` | `int` | Unchanged |
| `allocationMethod` | `ExpenseAllocationMethod?` | Unchanged shape; `null` only for a group |
| `allocationValue` | `double?` | Same as `allocationMethod` |

## Pending Item Edit — replaces Pending Formula Edit (widened per research.md Decision 1)

**Old type** (`ExpenseFormulaEdit`, removed): held only `method` + `value`, both required — could only ever represent "the user changed the formula," never a metadata-only change.

**New type** (`PendingItemEdit`, replaces it):

| Field | Type | Meaning when non-null | Meaning when null |
|---|---|---|---|
| `name` | `String?` | Staged new name | Name unchanged from the last-committed item |
| `iconKey` | `String?` | Staged new icon key | Icon unchanged |
| `description` | `String?` | Staged new description (note: a staged *clear* of an existing description needs its own explicit representation — see Open Question below, since `null` here already means "unchanged") |
| `method` | `ExpenseAllocationMethod?` | Staged new allocation mode | Mode unchanged |
| `value` | `double?` | Staged new allocation value | Value unchanged |

**Invariant**: at least one field is non-null (an entry only exists in the map because *something* was staged — an all-null `PendingItemEdit` should never be constructed; the dialog's `save()` only writes an entry when the user actually changed something relative to the item it opened with).

**Open question for `/speckit-tasks` / implementation, not blocking this plan**: `description` is the one field whose "no change" and "explicitly cleared to empty" states collide under plain `String?` nullability (`name`/`iconKey` can't meaningfully be cleared to empty in this UI; `description`'s field is optional even on a committed item). If clearing an existing description via the dialog turns out to matter in practice, `PendingItemEdit.description` needs a tri-state wrapper (unchanged / cleared / set-to-X) instead of plain `String?` — deferred to implementation time since the spec doesn't call out this edge case explicitly and today's dialog already sends `''` through `TextField.onChanged` indistinguishably either way.

**Provider rename** (research.md Decision 1): `pendingFormulaEditsProvider` (`Map<String, ExpenseFormulaEdit>`) → `pendingItemEditsProvider` (`Map<String, PendingItemEdit>`), keyed by item id exactly as before — no change to the keying/one-entry-per-item invariant (spec.md Edge Cases §1).

## State flow (for implementation reference, not a new entity)

```text
Dialog opened for existing LEAF item
  ├─ user edits name/icon/description/mode/value
  ├─ taps "Lưu" inside dialog
  │    ├─ FR-006 over-budget check on the candidate formula
  │    │    ├─ FAILS → dialog stays open, inline error, nothing staged (unchanged from today's create-dialog behavior)
  │    │    └─ PASSES → PendingItemEdit written to pendingItemEditsProvider[item.id], dialog closes
  ├─ tree provider overlays the pending edit onto this item everywhere it's read
  │    (list's static label, group's live subtotal, allocation-summary banner)
  └─ "Lưu công thức" (or tab-switch prompt's "Lưu") pressed
       ├─ full-plan over-budget validation across ALL pending entries
       │    ├─ FAILS → error surfaced, map untouched, nothing written
       │    └─ PASSES → repository.update()/saveFormulas() writes every pending entry,
       │                pendingItemEditsProvider cleared to {}

Dialog opened for existing GROUP item  → unchanged: repository.update() on "Lưu", immediate, no staging
Dialog opened with existingItem == null (create) → unchanged: repository.create() on "Lưu", immediate, no staging
```
