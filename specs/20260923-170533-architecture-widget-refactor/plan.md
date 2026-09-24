# Implementation Plan: Architecture Audit and Shared Widget Refactor

**Branch**: `20260923-170533-architecture-widget-refactor` | **Date**: 2026-09-23 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/20260923-170533-architecture-widget-refactor/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Audit all production Dart source and directly related tests against the project's
feature-first Clean Architecture rules, then apply the smallest behavior-preserving
refactors for confirmed violations. The first concrete shared-widget change is to
move the duplicated dashed-top-border painter into `core/widgets` and update both
feature consumers. The highest-risk boundary work is to stop `expenses` from
depending on `expense_control` presentation internals by introducing an explicit
application-facing read/write contract and moving concrete repository wiring out of
presentation. Feature-specific group cards, item rows, and account fields remain
local unless the audit proves an equivalent contract.

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: Dart 3.11 / Flutter SDK (existing project)

**Primary Dependencies**: Flutter Material/widgets, `flutter_riverpod`, Drift,
Supabase Flutter, GoRouter, existing localization and theme utilities. No new
runtime dependency is required.

**Storage**: Existing Drift/SQLite local database with the existing outbox and
Supabase synchronization boundaries; no schema change is planned.

**Testing**: `flutter analyze`, `dart format --output=none --set-exit-if-changed`,
`flutter test`, focused widget/unit tests for changed contracts, and existing
integration tests for affected user flows.

**Target Platform**: Existing Android and iOS Flutter application.

**Project Type**: Feature-first mobile application.

**Performance Goals**: Preserve the constitution's 60 fps list/animation budget,
avoid widening Riverpod rebuild scopes, and introduce no synchronous I/O or new
network work in widgets.

**Constraints**: Preserve navigation, validation, localization, error states,
offline-first persistence, and existing public behavior. `core/` may contain only
code shared by at least two features or explicitly justified composition
infrastructure. Domain code must remain free of Flutter, Drift, and Supabase.
Generated files, build artifacts, platform scaffolding, and historical specs are
out of scope unless runtime behavior requires review.

**Scale/Scope**: All production Dart files under `lib/` and directly related tests;
initial implementation focuses on the confirmed cross-feature dependency paths,
the duplicated dashed-border widget, application orchestration currently living in
presentation providers, and Supabase exception classification in the account UI.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principle I — Code Quality: PASS.** The plan keeps business rules out of
  `build()` and moves confirmed orchestration toward testable application/domain
  boundaries. No dead-code or lint suppression is introduced.
- **Principle II — Testing Standards: PASS with required coverage work.** Existing
  analyze/test baselines are healthy. The plan adds focused tests for the shared
  border contract, application contracts, and changed feature consumers.
- **Principle III — UX Consistency and Localization: PASS.** The shared widget is
  presentation-only and consumes explicit visual inputs. Feature localization and
  semantics remain at the owning feature boundary; no hardcoded UI strings are added.
- **Principle IV — Performance: PASS.** The plan removes duplicate painters and
  avoids new I/O, eager list work, or broad rebuild scopes.
- **Clean Architecture layering: PASS with planned corrections.** The audit found
  `expenses` imports `expense_control` presentation/domain internals and concrete
  repository wiring in presentation. The plan addresses these as explicit targets.
- **Offline-first and security: PASS.** No storage, sync, authentication, RLS,
  secret handling, or network behavior changes are proposed.
- **Complexity gate: PASS.** No new package, top-level project, or generic widget
  framework is required.

## Project Structure

### Documentation (this feature)

```text
specs/20260923-170533-architecture-widget-refactor/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── audit.md              # Source-area findings, evidence, and residual risks
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
lib/
├── core/
│   ├── di/                                  # repository/application composition
│   └── widgets/
│       ├── dashed_border.dart                # shared dashed rectangle/top border
│       └── empty_state_view.dart             # existing shared state widget
├── features/
│   ├── expense_control/
│   │   ├── data/                             # concrete repository implementation
│   │   ├── domain/                           # entities, pure plan rules, interfaces
│   │   └── presentation/                     # thin state adapters and screens
│   ├── expenses/
│   │   ├── application/                      # read/write contracts and use cases
│   │   └── presentation/                     # screens consume application contracts
│   └── account/
│       ├── application/                      # auth error/use-case boundary as needed
│       └── presentation/                     # screens render application outcomes
test/
├── unit/
├── widget/
└── integration/
```

**Structure Decision**: Retain the existing Flutter feature-first layout and add
only the smallest missing boundaries. `core/widgets` owns presentation primitives
used across features; feature-specific widgets remain under their feature. The
`expenses` feature will depend on an explicit application-facing contract rather
than importing `expense_control/presentation`. Concrete repository construction
belongs in composition/DI, while domain entities and rules remain in the owning
feature.

The final audit must also record domain/data line coverage and affected-screen
performance evidence required by the constitution, including any justified
residual risk where a device-level measurement is unavailable.

## Phase 0: Research Summary

Research is recorded in [research.md](./research.md). The repository baseline is
healthy (`flutter analyze` clean and 279 tests passing), but the audit found
cross-feature presentation imports, presentation-owned orchestration, concrete
data construction in presentation, and a Supabase exception type classified in a
widget. The lowest-risk shared extraction is the duplicated dashed-top-border
primitive.

## Phase 1: Design Summary

- [data-model.md](./data-model.md) defines the audit finding, shared widget
  contract, and refactor outcome records.
- [contracts/architecture-audit-record.md](./contracts/architecture-audit-record.md)
  defines the required evidence for each finding and disposition.
- [contracts/shared-widget-contract.md](./contracts/shared-widget-contract.md)
  defines the feature-neutral inputs and behavior required for `core/widgets`.
- [quickstart.md](./quickstart.md) defines formatting, analysis, focused tests,
  full tests, and regression checks required before completion.

## Complexity Tracking

No constitution violations are accepted. The application-facing contract and
composition boundary are the minimum structure needed to remove a concrete
cross-feature presentation dependency while preserving feature ownership; a broad
generic widget framework and wholesale feature rewrite are explicitly rejected.
