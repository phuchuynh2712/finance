# Data Model: Architecture Audit and Shared Widget Refactor

## Architecture Finding

A documented observation about source ownership or dependency direction.

| Field | Description | Validation |
|---|---|---|
| `id` | Stable finding identifier | Unique within the audit record |
| `location` | Source file or source-area path | Must point to an existing production or test path |
| `category` | Boundary, orchestration, DI, duplication, testability, or external dependency | One primary category required |
| `currentResponsibility` | What the code currently decides or owns | Concrete and behavior-based |
| `expectedBoundary` | Layer or feature that should own the responsibility | Must align with constitution layering |
| `impact` | User-facing and maintenance consequence | Must explain why the finding matters |
| `priority` | P1, P2, or P3 | P1 is behavior/risk critical; P2 is structural; P3 is cleanup |
| `disposition` | Refactor, retain, defer, or investigate | Must include rationale |
| `verification` | Tests, analysis, or review evidence | Required for completed findings |

## Shared Widget Contract

A feature-neutral presentation component used by at least two feature areas.

| Field | Description | Validation |
|---|---|---|
| `name` | Public widget name | Describes presentation behavior, not a domain entity |
| `consumers` | Feature areas using it | At least two equivalent consumers for `core/widgets` |
| `inputs` | Visual values and child content | Explicit, typed, and feature-neutral |
| `callbacks` | User interaction outputs | Optional callbacks; no repository or provider dependency |
| `states` | Supported visual states | All documented states preserve existing behavior |
| `localization` | Text ownership | Text stays with consumer or generated localization input |
| `semantics` | Accessibility contract | Labels and actions remain screen-reader reachable |
| `variants` | Intentional differences | Must be explicit rather than hidden feature imports |

## Refactor Outcome

The result of applying or deferring an architecture finding.

| Field | Description | Validation |
|---|---|---|
| `findingId` | Link to the source finding | Must resolve to one Architecture Finding |
| `changedPaths` | Files added, changed, or removed | Must be scoped to the finding |
| `preservedBehavior` | User outcomes that remain unchanged | Must cover affected navigation, validation, localization, and persistence where relevant |
| `testEvidence` | Focused and full verification results | Must include the command or test scope |
| `status` | Completed or deferred | Deferred outcomes require a reason and follow-up |
| `residualRisk` | Known remaining risk | Required even when empty, using `None identified` |

## Relationships

- One **Architecture Finding** can produce one or more **Refactor Outcomes** when migrated in slices.
- One **Shared Widget Contract** can be referenced by multiple feature consumers.
- A **Refactor Outcome** must reference the **Architecture Finding** it resolves and the **Shared Widget Contract** when the outcome changes a reusable widget.
