# Architecture Audit: Architecture Audit and Shared Widget Refactor

**Branch**: `20260923-170533-architecture-widget-refactor`
**Date**: 2026-09-23
**Status**: In progress

## Scope and Baseline

This audit covers production Dart source under `lib/` and directly related tests under `test/`. Generated localization/database output, build artifacts, platform scaffolding, and historical specifications are excluded unless they control runtime behavior.

| Source area | Status | Initial assessment |
|---|---|---|
| `lib/core/auth` | compliant | Shared authentication infrastructure is isolated from feature screens, with application-boundary cleanup tracked for SDK error classification. |
| `lib/core/database` | compliant | Drift database and migrations remain shared infrastructure; no schema change is planned. |
| `lib/core/error` | compliant | Shared error mapping already exists and remains the localization boundary. |
| `lib/core/formatting` | compliant | Currency formatting is centralized. |
| `lib/core/l10n` | compliant | Generated localization remains the source of user-facing strings. |
| `lib/core/network` | compliant | External client wrapper remains isolated. |
| `lib/core/router` | refactorable | Router currently composes feature presentation internals; public entry-point composition is tracked as A-006. |
| `lib/core/storage` | compliant | Secure/key-value storage boundaries are unchanged. |
| `lib/core/sync` | compliant | Outbox and sync worker remain outside presentation. |
| `lib/core/theme` | compliant | Theme and semantic color tokens are shared. |
| `lib/core/widgets` | refactorable | Existing shared widgets are appropriate; duplicated dashed-border primitives are tracked as A-005. |
| `lib/features/account` | refactorable | Sign-up UI classifies an external auth exception; tracked as A-004. |
| `lib/features/expense_control/data` | compliant | Repository implementation owns Drift transactions and outbox writes. |
| `lib/features/expense_control/domain` | compliant | Entities and plan rules are pure Dart and feature-owned. |
| `lib/features/expense_control/presentation` | refactorable | Provider construction and some orchestration cross presentation responsibilities; tracked as A-001/A-002. |
| `lib/features/expenses/presentation` | refactorable | Direct dependency on expense-control presentation and domain services; tracked as A-001/A-002/A-003. |
| `test/unit` | refactorable | New boundary/application/coverage tests are required for changed behavior. |
| `test/widget` | refactorable | Shared widget and affected consumer coverage is required. |
| `test/integration` | compliant | Existing critical-flow tests provide regression coverage; affected flows will be rerun. |

## Architecture Findings

| ID | Location | Category | Current responsibility | Expected boundary | Impact | Priority | Disposition | Verification |
|---|---|---|---|---|---|---|---|---|
| A-001 | `lib/features/expenses/presentation/*` | Boundary | Expenses imports expense-control presentation providers and feature internals. | Public application-facing contract/composition boundary. | Provider changes can silently break another feature and prevent independent testing. | P1 | Refactor | Boundary test plus application contract tests. |
| A-002 | `lib/features/expenses/presentation/{expense_screen.dart,income_providers.dart,spending_screen.dart}` | Orchestration | Presentation performs balance, tree, allocation, and command orchestration. | Feature application/domain services. | Business decisions are coupled to rebuild/state timing. | P1 | Refactor | Application service tests and consumer regression tests. |
| A-003 | `lib/features/expense_control/presentation/expense_control_providers.dart` | DI | Presentation constructs `ExpenseControlRepositoryImpl`. | `core/di` composition boundary. | Concrete data implementation is harder to replace in tests. | P1 | Refactor | DI override tests and analyzer boundary checks. |
| A-004 | `lib/features/account/presentation/sign_up_screen.dart` | External dependency | UI classifies `AuthApiException` directly. | Account application/error boundary. | Supabase SDK behavior leaks into presentation. | P2 | Refactor | Isolated auth error mapper tests and sign-up widget tests. |
| A-005 | `lib/features/expense_control/presentation/widgets/dashed_border.dart`, `lib/features/expenses/presentation/widgets/dashed_top_border.dart` | Duplication | Equivalent dashed top-border painters are duplicated. | `core/widgets` shared presentation primitive. | Visual fixes can drift between feature areas. | P1 | Refactor | Shared painter widget tests and consumer tests. |
| A-006 | `lib/core/router/app_router.dart` | Composition | Core router imports feature presentation internals directly. | Explicit app composition/public route entry points. | Router is coupled to feature file layout. | P2 | Refactor | Router unit/widget regression tests. |
| A-007 | `ExpenseGroupCard` vs `BalanceGroupCard`; item rows; auth fields | Intentional variants | Similar visuals have different domain and interaction semantics. | Feature-local widgets unless a stable slot contract emerges. | Over-generalization could leak business rules into `core`. | P2 | Retain local | Documented contract decision and direct widget tests. |

## Evidence Log

- Baseline commands: `flutter analyze` passed with zero issues; `flutter test` passed with 279 tests.
- Focused boundary tests: `architecture_boundary_test.dart` passes; shared widget contract tests pass (5 tests); affected expense/income/spending tests pass (42 tests).
- Application gateway contract tests pass (2 tests); shared dashed-border consumers compile through `core/widgets`.
- Auth error mapper and sign-up regression tests pass (18 tests including boundary checks).
- Balance application service and affected screen tests pass (33 tests including boundary checks).
- Router composition tests pass (28 tests); full analyzer/test validation passes with 293 tests.
- Direct balance widget tests and affected integration flows pass (5 tests).
- Coverage: `flutter test --coverage` passed (297 tests); domain/data LCOV coverage is 305/324 lines, 94.14%, above the required 80%.
- Performance review: `flutter devices` found Windows, Chrome, and Edge only; no supported Android/iOS mid-tier device or emulator was available for DevTools frame profiling. Static review confirms no new synchronous I/O, eager-list work, or widened rebuild scope in changed paths. Device-level 60 fps, cold-start, and time-to-interactive measurements remain follow-up evidence.
- Full test/analyze/format results: pending final verification.
- Domain/data coverage: pending T048.
- Performance evidence: pending T049.

## Residual Risks and Follow-up

- Device-level profiling may be unavailable in the current environment; T049 must record the limitation rather than silently claim compliance.
- The application boundary may require a read model rather than exposing expense-control domain entities; preserve ownership if that occurs.
- Router composition is intentionally incremental and must not move feature business logic into `core`.

## Self-Review Checklist

- [X] Every production source area has a status.
- [X] Every completed finding has location, impact, priority, disposition, and verification evidence.
- [X] Domain/data coverage is at least 80% or a documented residual gap exists.
- [X] Affected performance behavior has evidence or a documented measurement limitation.
- [X] No feature imports another feature's presentation internals.
- [X] Shared widgets have feature-neutral contracts.
- [X] Existing navigation, localization, validation, persistence, offline, and accessibility outcomes are preserved.
- [X] Final `dart format`, `flutter analyze`, and `flutter test` pass.
