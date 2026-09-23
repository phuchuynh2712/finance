# Research: Architecture Audit and Shared Widget Refactor

**Date**: 2026-09-23
**Scope**: Production Dart source under `lib/` and directly related tests

## Decision 1: Preserve the existing feature-first Clean Architecture shape

**Decision**: Keep `lib/core`, `lib/features/<feature>/{presentation,domain,data}`, Riverpod, Drift, and the existing repository interfaces. Correct dependency direction incrementally instead of rewriting the project structure.

**Rationale**: The constitution already defines this structure, and the repository contains healthy examples: pure expense-control domain models/services, repository interfaces in domain, and Drift/outbox work in data. A wholesale rewrite would increase regression risk without improving the governing boundaries.

**Alternatives considered**:
- A global layers-only rewrite: rejected because it would weaken feature ownership and create a large migration surface.
- Moving all expense-control models into `core`: rejected because they are feature-specific business concepts, not shared infrastructure.

## Decision 2: Treat `expenses` to `expense_control` presentation imports as the first boundary correction

**Decision**: Introduce an explicit application-facing read/write contract or composition boundary for the expense flows, then make `expenses` consume that boundary rather than `expense_control/presentation` providers and widgets. Move concrete repository construction out of feature presentation composition where practical.

**Rationale**: The audit found direct imports from `expenses` into `expense_control/presentation`, plus screens that call expense-control domain services while building. This is the highest-risk violation because provider implementation changes can break another feature and make independent testing difficult.

**Alternatives considered**:
- Keep the imports and document them as an exception: rejected because it leaves the constitution violation in place.
- Move expense-control domain entities into `core`: rejected because it hides ownership rather than defining a stable application contract.
- Perform a complete use-case rewrite first: rejected because a narrow public contract can remove the dependency with less behavioral risk.

## Decision 3: Extract the dashed-border primitive into `core/widgets`

**Decision**: Consolidate the equivalent dashed top-border implementation into a shared core widget file, preserve its configurable color and dash geometry, and update all feature consumers. Keep the full rounded-rectangle primitive alongside it only if its consumers and contract are confirmed during implementation.

**Rationale**: The top-border painter is duplicated in `expense_control` and `expenses`, is presentation-only, and has no feature-specific state or localization. It satisfies the constitution's two-feature rule for `core/` and is the lowest-risk shared-widget change.

**Alternatives considered**:
- Keep two copies: rejected because visual fixes can drift.
- Introduce a third-party dashed-border package: rejected because the existing pure painter is small and already works.
- Create a generic card framework: rejected because group-card and item-row semantics differ materially.

## Decision 4: Keep semantically different cards and fields feature-local

**Decision**: Do not merge `ExpenseGroupCard` with `BalanceGroupCard`, `ExpenseItemRow` with `BalanceItemRow`, or account sign-in/sign-up fields based on visual similarity alone. Consider only small slot-based primitives after a third consumer or stable contract exists.

**Rationale**: Editable expense-control cards own mutation callbacks, staging, formula summaries, and domain semantics. Balance cards are read-only and display actual currency values. Account fields also differ in sizing, validation, error, and suffix behavior.

**Alternatives considered**:
- One highly parameterized generic card/row: rejected because it would leak domain concerns into shared presentation and make contracts harder to test.
- Extract every visually similar field immediately: rejected because it would flatten intentional UX differences before their contract is understood.

## Decision 5: Move presentation-owned orchestration incrementally

**Decision**: Treat calculations and commands currently performed by screens/providers as application or domain responsibilities, but migrate in focused slices with tests: balance view data, expense/income commands, repository wiring, and auth exception classification.

**Rationale**: The audit found `computeItemBalance`, `flattenLeaves`, allocation orchestration, repository construction, and Supabase exception classification crossing presentation boundaries. Incremental migration preserves behavior and gives each boundary a falsifiable test.

**Alternatives considered**:
- Leave all orchestration in Riverpod providers: rejected because those providers are acting as application services while remaining coupled to presentation and another feature's providers.
- Move all logic into domain in one pass: rejected because it risks changing state semantics and exceeds the smallest safe refactor.

## Baseline and verification

- Read-only audit covered all Dart files under `lib/` and relevant tests.
- Existing focused tests passed: 35 tests in the initial audit slice.
- Full repository baseline reported by the research pass: `flutter analyze` clean and 279 tests passing.
- Generated localization/database files, build artifacts, platform scaffolding, and historical specifications remain outside implementation scope unless runtime evidence requires otherwise.
