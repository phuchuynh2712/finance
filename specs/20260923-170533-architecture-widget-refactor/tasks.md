---

description: "Executable task list for the architecture audit and shared widget refactor"
---

# Tasks: Architecture Audit and Shared Widget Refactor

**Input**: Design documents from `specs/20260923-170533-architecture-widget-refactor/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/`, and `quickstart.md`

**Tests**: Included because the specification requires automated coverage for every changed behavior boundary and regression verification.

**Organization**: Tasks are grouped by prioritized user story. User Story 1 is the MVP audit and highest-risk boundary correction; User Story 2 handles shared presentation primitives; User Story 3 verifies preserved user outcomes.

## Phase 1: Setup

**Purpose**: Establish the audit record and capture a reproducible baseline before source changes.

- [X] T001 Create the architecture audit record template and source-area status table in `specs/20260923-170533-architecture-widget-refactor/audit.md`
- [X] T002 Inventory production Dart files and directly related tests under `lib/` and `test/` in `specs/20260923-170533-architecture-widget-refactor/audit.md`
- [X] T003 Run `flutter analyze` and `flutter test`, then record baseline results and test count in `specs/20260923-170533-architecture-widget-refactor/audit.md`
- [X] T004 [P] Verify the active branch, feature pointer, and plan paths in `specs/20260923-170533-architecture-widget-refactor/quickstart.md`

---

## Phase 2: Foundational

**Purpose**: Define and test the boundaries that all user-story refactors depend on.

**Checkpoint**: Boundary contracts and baseline evidence are ready before implementation changes begin.

- [X] T005 [P] Add architecture boundary assertions for forbidden domain imports and cross-feature presentation imports in `test/unit/architecture/architecture_boundary_test.dart`
- [X] T006 [P] Add shared widget contract test scaffolding for feature-neutral inputs and absence of feature dependencies in `test/widget/core/shared_widget_contract_test.dart`
- [X] T007 Define the public application-facing expense read/write contract and dependency direction in `lib/features/expenses/application/expense_control_gateway.dart`
- [X] T008 Define the provider/composition seam for the expense application contract without constructing concrete repositories in `lib/core/di/expense_dependencies.dart`
- [X] T009 Document the audit finding IDs, dispositions, residual risks, and acceptance evidence in `specs/20260923-170533-architecture-widget-refactor/audit.md`

---

## Phase 3: User Story 1 - Understand and prioritize architecture issues (Priority: P1) 🎯 MVP

**Goal**: Classify every production source area and correct the highest-risk feature boundary so maintainers have an auditable, testable architecture baseline.

**Independent Test**: Every production source area has a status in `audit.md`; architecture boundary tests pass; `expenses` no longer imports `expense_control` presentation internals; focused application tests verify equivalent outcomes.

### Tests for User Story 1

- [X] T010 [P] [US1] Add contract tests for the expense application gateway's read, write, error, and loading outcomes in `test/unit/features/expenses/application/expense_control_gateway_test.dart`
- [X] T011 [P] [US1] Add tests for provider overrideability and fake repository composition in `test/unit/core/di/expense_dependencies_test.dart`
- [X] T012 [P] [US1] Add application tests for balance view data and group totals without Flutter widget construction in `test/unit/features/expenses/application/balance_view_service_test.dart`
- [X] T013 [P] [US1] Add application tests for expense and income command validation, allocation, and write-failure outcomes in `test/unit/features/expenses/application/transaction_command_service_test.dart`
- [X] T014 [P] [US1] Add isolated tests for authentication exception classification and localized error categories in `test/unit/features/account/application/auth_error_mapper_test.dart`

### Implementation for User Story 1

- [X] T015 [US1] Move concrete `ExpenseControlRepositoryImpl` construction out of `lib/features/expense_control/presentation/expense_control_providers.dart` into `lib/core/di/expense_dependencies.dart` while preserving test overrides
- [X] T016 [US1] Implement the expense-control gateway adapter over the existing repository and plan service in `lib/features/expenses/application/expense_control_gateway.dart`
- [X] T017 [US1] Replace imports of `lib/features/expense_control/presentation/expense_control_providers.dart` from `lib/features/expenses/presentation/expense_providers.dart` and `lib/features/expenses/presentation/income_providers.dart` with the application-facing contract
- [X] T018 [US1] Replace direct expense-control provider and presentation imports in `lib/features/expenses/presentation/expense_screen.dart`, `lib/features/expenses/presentation/income_screen.dart`, and `lib/features/expenses/presentation/spending_screen.dart` with application contracts
- [X] T019 [US1] Move balance preparation and `computeItemBalance` orchestration out of `lib/features/expenses/presentation/spending_screen.dart` into `lib/features/expenses/application/balance_view_service.dart`
- [X] T020 [US1] Move expense tree flattening, validation, and write-command orchestration out of `lib/features/expenses/presentation/expense_providers.dart` into `lib/features/expenses/application/transaction_command_service.dart`
- [X] T021 [US1] Move income tree construction and allocation orchestration out of `lib/features/expenses/presentation/income_providers.dart` into `lib/features/expenses/application/transaction_command_service.dart`
- [X] T022 [US1] Move Supabase exception classification out of `lib/features/account/presentation/sign_up_screen.dart` into `lib/features/account/application/auth_error_mapper.dart` while preserving existing localized duplicate-email behavior
- [X] T023 [US1] Update `lib/core/router/app_router.dart` to compose public feature route builders or entry points without importing feature presentation internals beyond the composition boundary
- [X] T024 [US1] Record completed, retained, and deferred architecture findings with paths and verification evidence in `specs/20260923-170533-architecture-widget-refactor/audit.md`

**Checkpoint**: User Story 1 is independently complete when the audit is comprehensive, boundary tests pass, `expenses` has no presentation-internal dependency on `expense_control`, and the changed application services have focused tests.

---

## Phase 4: User Story 2 - Use shared widgets consistently (Priority: P2)

**Goal**: Consolidate equivalent cross-feature presentation primitives while keeping semantically different widgets feature-local.

**Independent Test**: Both feature areas render the same shared dashed-border implementation; direct shared-widget tests pass; group cards, item rows, and account fields remain local with their differences documented.

### Tests for User Story 2

- [X] T025 [P] [US2] Add widget tests for `DashedTopBorder` defaults, configurable dash geometry, color, and child layout in `test/widget/core/widgets/dashed_border_test.dart`
- [X] T026 [P] [US2] Add widget tests for `DashedRectBorder` defaults, radius, stroke, and child layout in `test/widget/core/widgets/dashed_border_test.dart`
- [X] T027 [P] [US2] Add direct tests for shared `EmptyStateView` message-only, CTA, callback, and semantics behavior in `test/widget/core/widgets/empty_state_view_test.dart`
- [X] T028 [P] [US2] Extend feature consumer tests to cover dashed separators in `test/widget/features/expense_control/expense_group_card_test.dart` and `test/widget/features/expenses/income_screen_test.dart`

### Implementation for User Story 2

- [X] T029 [US2] Create the feature-neutral dashed border primitives with preserved defaults and explicit visual inputs in `lib/core/widgets/dashed_border.dart`
- [X] T030 [US2] Replace the expense-control dashed-border implementation with imports from `lib/core/widgets/dashed_border.dart` in `lib/features/expense_control/presentation/expense_control_screen.dart` and `lib/features/expense_control/presentation/widgets/expense_group_card.dart`
- [X] T031 [US2] Replace the expenses dashed-border implementation with imports from `lib/core/widgets/dashed_border.dart` in `lib/features/expenses/presentation/income_screen.dart` and `lib/features/expenses/presentation/widgets/balance_group_card.dart`
- [X] T032 [US2] Remove obsolete feature-local dashed-border files `lib/features/expense_control/presentation/widgets/dashed_border.dart` and `lib/features/expenses/presentation/widgets/dashed_top_border.dart` after all consumers migrate
- [X] T033 [US2] Document retained feature-local widget decisions for `ExpenseGroupCard`, `BalanceGroupCard`, `ExpenseItemRow`, `BalanceItemRow`, and account form fields in `specs/20260923-170533-architecture-widget-refactor/audit.md`

**Checkpoint**: User Story 2 is independently complete when the shared dashed-border contract has one implementation, all known consumers use it, focused widget tests pass, and no semantically different widget was merged without an explicit contract.

---

## Phase 5: User Story 3 - Preserve existing user outcomes (Priority: P3)

**Goal**: Demonstrate that architecture and widget refactors preserve navigation, validation, localization, persistence, offline behavior, and accessibility.

**Independent Test**: Targeted affected flows and the complete automated suite pass with no new analyzer issues or user-visible regressions.

### Tests for User Story 3

- [X] T034 [P] [US3] Update account flow tests for sign-up duplicate-email and generic-error behavior in `test/widget/features/account/sign_up_screen_test.dart`
- [X] T035 [P] [US3] Update expense flow tests for valid, invalid, submitting, and write-failure behavior in `test/widget/features/expenses/expense_screen_test.dart`
- [X] T036 [P] [US3] Update income flow tests for allocation validation, write failure, localization, and navigation outcomes in `test/widget/features/expenses/income_screen_test.dart`
- [X] T037 [P] [US3] Update spending flow tests for read-only balance rendering, positive/negative values, empty state, and navigation in `test/widget/features/expenses/spending_screen_test.dart`
- [X] T038 [P] [US3] Add direct read-only behavior tests for group and item balance widgets in `test/widget/features/expenses/balance_group_card_test.dart` and `test/widget/features/expenses/balance_item_row_test.dart`
- [X] T039 [P] [US3] Run authentication/preferences coverage in `test/integration/profile_preferences_persistence_test.dart` and expense-control flow coverage in `test/integration/expense_control_flow_test.dart`, recording outcomes in `specs/20260923-170533-architecture-widget-refactor/audit.md`

### Implementation and verification for User Story 3

- [X] T040 [US3] Preserve generated localization usage and verify Vietnamese and English outcomes in `test/widget/features/account/sign_up_screen_test.dart`, `test/widget/features/expenses/income_screen_test.dart`, and `test/widget/features/expenses/expense_screen_test.dart`
- [X] T041 [US3] Verify theme, touch-target, semantics, and light/dark rendering contracts with `test/unit/core/theme/app_theme_test.dart`, `test/widget/core/widgets/empty_state_view_test.dart`, and affected feature widget tests
- [X] T042 [US3] Verify offline-first local writes, repository boundaries, and outbox behavior with `test/unit/features/expense_control/expense_control_repository_impl_test.dart` and `test/unit/core/sync/sync_worker_test.dart`
- [X] T043 [US3] Run `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, and `flutter test`, then record results in `specs/20260923-170533-architecture-widget-refactor/audit.md`

**Checkpoint**: User Story 3 is independently complete when all affected flows retain their intended outcomes and the full verification suite passes.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Close documentation, residual-risk, and final quality gaps across the completed stories.

- [X] T044 [P] Update `specs/20260923-170533-architecture-widget-refactor/audit.md` with final source-area coverage, completed findings, deferred findings, residual risks, and follow-up work
- [X] T045 [P] Update `specs/20260923-170533-architecture-widget-refactor/quickstart.md` with any implementation-specific command or test-path corrections discovered during execution
- [X] T046 [P] Complete the documented self-review checklist for changed public classes, methods, and widgets, including single responsibility, dead code, stale comments, and constitution compliance, in `specs/20260923-170533-architecture-widget-refactor/audit.md`
- [X] T047 Run the complete quickstart validation and confirm all success criteria in `specs/20260923-170533-architecture-widget-refactor/spec.md` are evidenced by `specs/20260923-170533-architecture-widget-refactor/audit.md`
- [X] T048 Run `flutter test --coverage`, verify domain/data line coverage is at least 80%, and record the coverage summary and any residual gap in `specs/20260923-170533-architecture-widget-refactor/audit.md`
- [X] T049 Profile affected scrolling/animation flows and record 60 fps, rebuild-scope, and device-performance evidence or a documented limitation in `specs/20260923-170533-architecture-widget-refactor/audit.md`
- [X] T050 Add router composition regression coverage for public entry points and navigation guards in `test/unit/core/router/app_router_test.dart` and `test/widget/core/router/app_shell_test.dart`
- [X] T051 Run the final constitution self-review against `specs/20260923-170533-architecture-widget-refactor/audit.md` before implementation handoff

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies; establishes the audit scope and baseline.
- **Phase 2 (Foundational)**: Depends on Phase 1; blocks implementation because contracts and boundary tests define the safe refactor shape.
- **Phase 3 (US1)**: Depends on Phase 2; delivers the MVP architecture audit and highest-risk boundary correction.
- **Phase 4 (US2)**: Depends on Phase 2 and can run in parallel with US1 after the shared widget contract is established.
- **Phase 5 (US3)**: Depends on the relevant completed changes from US1 and US2; validates all affected existing flows.
- **Phase 6 (Polish)**: Depends on all desired user stories and final verification.

### User Story Dependencies

- **US1 (P1)**: Depends on Foundational tasks; no dependency on US2; MVP scope.
- **US2 (P2)**: Depends on Foundational tasks; independent of US1 implementation except for the shared audit record.
- **US3 (P3)**: Depends on US1 and US2 changes because it verifies their preserved behavior; test preparation can begin in parallel.

### Parallel Opportunities

- Setup: T004 can run in parallel with the audit drafting; T002 follows T001 because both update `audit.md`, and T003 consumes the baseline environment.
- Foundational: T005 and T006 can run in parallel; T007 and T008 should be coordinated because they define the same application boundary.
- US1: T010-T014 can run in parallel as test files are independent; T015, T019, T020, T021, and T022 can proceed in parallel after their tests/contracts are defined, while T017-T018 depend on T016.
- US2: T025-T028 can run in parallel; T029 must complete before T030-T032, while T033 can run in parallel with implementation.
- US3: T034-T039 can run in parallel; T040-T042 can be reviewed in parallel before T043.
- Polish: T044-T046 can run in parallel; T048-T050 can run in parallel after implementation; T047 and T051 run last.

## Parallel Example: User Story 1

```text
Task: "Add expense gateway contract tests in test/unit/features/expenses/application/expense_control_gateway_test.dart"
Task: "Add DI override tests in test/unit/core/di/expense_dependencies_test.dart"
Task: "Add balance service tests in test/unit/features/expenses/application/balance_view_service_test.dart"
Task: "Add transaction command service tests in test/unit/features/expenses/application/transaction_command_service_test.dart"
Task: "Add auth error mapper tests in test/unit/features/account/application/auth_error_mapper_test.dart"
```

## Parallel Example: User Story 2

```text
Task: "Test dashed border primitives in test/widget/core/widgets/dashed_border_test.dart"
Task: "Test EmptyStateView in test/widget/core/widgets/empty_state_view_test.dart"
Task: "Extend expense-control consumer coverage in test/widget/features/expense_control/expense_group_card_test.dart"
Task: "Extend income consumer coverage in test/widget/features/expenses/income_screen_test.dart"
```

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 baseline and audit setup.
2. Complete Phase 2 boundary contracts and foundational tests.
3. Complete Phase 3 to classify all source areas and remove the highest-risk cross-feature presentation dependency.
4. Stop and validate the independent US1 criteria with focused tests, `flutter analyze`, and the recorded audit evidence. The final implementation still requires T048-T051 before handoff.

### Incremental Delivery

1. Complete Setup and Foundational phases.
2. Deliver US1 as the architecture-audit MVP.
3. Deliver US2 as the shared-widget consolidation slice.
4. Deliver US3 as the compatibility and regression gate.
5. Complete Polish only after all desired refactors and tests pass.

### Parallel Team Strategy

1. One contributor owns the audit and boundary contracts.
2. A second contributor can implement the shared dashed-border extraction after T006/T029's contract is agreed.
3. A third contributor can prepare US3 regression tests while US1 and US2 implementation proceeds.
4. Integrate through the focused verification tasks before running the full suite.

## Notes

- Every task starts with `- [ ]`, has a sequential `T###` ID, and includes exact repository paths.
- `[P]` appears only on tasks that can work on independent files or evidence.
- `[US1]`, `[US2]`, and `[US3]` appear on all user-story phase tasks.
- Tests are included because the feature specification explicitly requires automated coverage and regression evidence.
- Do not genericize semantically different cards or fields solely to reduce visual duplication.
