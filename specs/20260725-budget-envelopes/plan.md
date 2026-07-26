# Implementation Plan: Budget Envelopes

**Branch**: `20260725-budget-envelopes` | **Date**: 2026-07-26 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/20260725-budget-envelopes/spec.md`

## Summary

Users configure budget envelopes (percentage-of-income or fixed-amount), allocate income into them via a "Plan" action (additive, repeatable per month, with deterministic rounding-remainder and over-allocation handling), track spending against envelopes with inline overspend coverage from another envelope, and navigate the app through 4 bottom-nav tabs (Overview, Spending, Envelopes, Account). This is also the first feature to actually wire up the app's core infrastructure — local database, navigation shell, and authentication gate — since the scaffold so far only has a single connectivity-check screen. Technical approach: Drift (SQLite) as the offline source of truth with an outbox-pattern sync to Supabase per the constitution's Offline-First mandate; `go_router`'s `StatefulShellRoute` for the 4-tab shell with per-tab state preservation; Riverpod (plain providers, matching the existing `connection_test` feature's style — no code generation) for state/DI; all money math done in integer VND via pure, unit-tested Dart use cases in `domain/`.

## Technical Context

**Language/Version**: Dart (SDK `^3.11.0`), Flutter stable

**Primary Dependencies**: `flutter_riverpod` (state/DI), `drift` + `drift_flutter` + `sqlite3_flutter_libs` (local DB), `supabase_flutter` (auth + Postgres sync backend), `go_router` (navigation — first real use in this codebase), `intl` (VND currency formatting), `flutter_secure_storage` (already used for Supabase session tokens)

**Storage**: Drift/SQLite is the local source of truth for all reads/writes (envelopes, allocation events + their per-envelope breakdown lines, expense entries, envelope coverages); Supabase Postgres is the sync target, reached only through an outbox queue — never written to synchronously from the UI path

**Testing**: `flutter_test` for unit + widget tests; unit tests cover 100% of the allocation-calculation, rounding-remainder, over-allocation-detection, overspend-detection, and expense edit/delete reversal logic (all pure Dart, no widget/DB dependency) to satisfy the constitution's 80% domain-coverage gate; widget tests for the Plan preview, expense entry + covering-envelope prompt, and Envelopes CRUD screens; one integration test exercising the full allocate → spend → overspend-coverage loop against an in-memory Drift database

**Target Platform**: Android + iOS (matches the existing app scaffold's platform scope; web/desktop remain out of scope per the icon/theme feature's precedent)

**Project Type**: Mobile app (Flutter, single codebase, feature-first Clean Architecture per constitution)

**Performance Goals**: Inherited from constitution Principle IV — 60fps on scrolling lists (envelope list, spending list), cold start <2s, dashboard (Overview) time-to-interactive <1s; SC-001/SC-003 additionally require the Plan flow and routine expense entry to each complete in well under those ceilings from a pure interaction-time perspective (not device performance)

**Constraints**: MUST work fully offline (constitution Offline-First) — every write in this feature (create/edit/delete envelope, confirm allocation, record/edit/delete expense) commits to Drift and enqueues to the sync outbox in the same local transaction, never blocking on network; all currency math MUST be integer VND arithmetic (no floating point) to satisfy SC-002's exact-sum guarantee

**Scale/Scope**: Single user per account (Supabase RLS-scoped, no shared/family envelopes in this spec); SC-001 targets responsiveness up to 10 envelopes; 4 tabs, ~7 screens (Overview, Plan preview/confirm, Spending list, Expense entry + covering-envelope prompt, Envelopes list, Envelope create/edit, Account)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle / Section | Applies? | How this feature satisfies it |
|---|---|---|
| I. Code Quality | Yes | `flutter analyze` zero-warnings gate unchanged; allocation/overspend math lives in `domain/` use cases, never inside `build()`; each screen's controller (Riverpod) is the only thing touching presentation state |
| II. Testing Standards | Yes | All allocation/rounding/over-allocation/overspend/expense-reversal logic is pure Dart in `domain/`, unit-tested to ≥80% line coverage; widget tests for Plan preview, expense entry, Envelopes CRUD; one integration test for the allocate→spend→cover loop |
| III. UX Consistency | Yes | Uses the existing shared `AppTheme`/`AppColors` (no new hardcoded colors); all new strings ship in both `app_vi.arb` and `app_en.arb` in the same PR; negative-balance/over-allocation flags reuse a single shared "flagged amount" widget rather than ad hoc red text per screen; currency values formatted only through a new shared `core/formatting/currency_formatter.dart` (VND, locale-aware) |
| IV. Performance | Yes | Envelope and spending lists use `ListView.builder`; allocation preview computation (pure Dart, in-memory, ≤10 envelopes) is trivially sub-frame-budget and does not need isolate offload; Drift queries indexed on `user_id` (all tables) and `envelope_id` (expense/coverage tables) |
| Recommended Architecture | Yes | Feature-first: `features/envelopes/`, `features/expenses/`, `features/account/`, each with `presentation/domain/data/`; cross-feature reads happen only through domain repository interfaces (e.g. `features/expenses` depends on `features/envelopes`'s `EnvelopeRepository` interface, never its `data/`); shared shell/router in `core/router/`, shared DB in `core/database/`, shared auth session in `core/auth/` |
| Offline-First Data & Sync | Yes | Drift is the source of truth; every write also appends to a `sync_outbox` row in the same transaction; a background worker (off UI isolate) drains it to Supabase with retry/backoff; envelope balances are recomputed server-side (Postgres view) and reconciled rather than trusted as final — see research.md §2 |
| Security | Yes | RLS enabled on all 5 new Supabase tables, scoped to `auth.uid() = user_id` (see `contracts/schema.sql`); no financial values in logs; Supabase session already goes through `flutter_secure_storage` (existing `core/network` setup) |
| Development Workflow | Yes | Feature branch already created (`20260725-budget-envelopes`); tests ship in the same PR as the logic they cover |

**Result**: PASS — no violations requiring Complexity Tracking justification.

**Post-Phase-1 re-check**: Confirmed against the completed `research.md`, `data-model.md`, and `contracts/schema.sql` — RLS policies exist on all 5 tables, the outbox and server-authoritative-balance-view mechanisms are concretely specified (not just asserted), and the feature-first module layout in Project Structure matches what `data-model.md`'s entities actually require. Still PASS, no new violations surfaced during design.

## Project Structure

### Documentation (this feature)

```text
specs/20260725-budget-envelopes/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md         # Phase 1 output
├── quickstart.md         # Phase 1 output
├── contracts/
│   └── schema.sql        # Phase 1 output — Supabase Postgres DDL + RLS policies
└── tasks.md              # Phase 2 output (/speckit-tasks — not created here)
```

### Source Code (repository root)

```text
lib/
├── core/
│   ├── auth/                          # NEW — session state provider + router auth guard
│   │   ├── auth_state_provider.dart   # Riverpod stream provider over Supabase auth state
│   │   └── auth_repository.dart       # sign in/out, change password, avatar update
│   ├── database/                      # NEW — first real use of the Drift dependency
│   │   ├── app_database.dart          # Drift AppDatabase, all 5 tables, migrations
│   │   └── tables/
│   │       ├── envelopes_table.dart
│   │       ├── allocation_events_table.dart
│   │       ├── allocation_event_lines_table.dart
│   │       ├── expense_entries_table.dart
│   │       └── envelope_coverages_table.dart
│   ├── sync/                          # NEW — outbox worker
│   │   ├── sync_outbox_table.dart
│   │   └── sync_worker.dart
│   ├── router/                        # NEW — first real use of go_router
│   │   └── app_router.dart            # StatefulShellRoute (4 tabs) + auth redirect guard
│   ├── formatting/                    # NEW
│   │   └── currency_formatter.dart    # VND-aware, via intl
│   ├── l10n/                          # existing — app_vi.arb / app_en.arb gain new keys
│   ├── network/                       # existing — supabase_client_provider.dart reused as-is
│   └── theme/                         # existing — reused as-is, no new tokens needed
├── features/
│   ├── envelopes/                     # NEW — Overview + Envelopes tabs, Plan/allocation flow
│   │   ├── domain/
│   │   │   ├── envelope.dart
│   │   │   ├── allocation_event.dart
│   │   │   ├── allocation_event_line.dart
│   │   │   ├── envelope_repository.dart
│   │   │   ├── allocation_repository.dart
│   │   │   └── compute_allocation_preview.dart   # pure calculation use case
│   │   ├── data/
│   │   │   ├── envelope_repository_impl.dart
│   │   │   └── allocation_repository_impl.dart
│   │   └── presentation/
│   │       ├── overview_screen.dart
│   │       ├── plan_screen.dart
│   │       ├── envelopes_screen.dart
│   │       └── envelope_form_screen.dart
│   ├── expenses/                      # NEW — Spending tab
│   │   ├── domain/
│   │   │   ├── expense_entry.dart
│   │   │   ├── envelope_coverage.dart
│   │   │   ├── expense_repository.dart
│   │   │   └── compute_overspend.dart            # pure calculation use case
│   │   ├── data/
│   │   │   └── expense_repository_impl.dart
│   │   └── presentation/
│   │       ├── spending_screen.dart
│   │       └── expense_form_screen.dart
│   ├── account/                       # NEW — Account tab
│   │   ├── domain/
│   │   │   └── account_use_cases.dart
│   │   └── presentation/
│   │       ├── account_screen.dart
│   │       └── sign_in_screen.dart
│   └── connection_test/               # existing — unchanged
└── main.dart                          # updated: ProviderScope root switches from
                                        # `home:` to `routerConfig:` (app_router.dart)

test/
├── unit/
│   ├── features/envelopes/domain/     # allocation math, rounding, over-allocation
│   └── features/expenses/domain/      # overspend detection, edit/delete reversal
├── widget/
│   └── features/                      # Plan preview, expense form, envelopes CRUD
└── integration/
    └── allocate_spend_cover_flow_test.dart
```

**Structure Decision**: Feature-first Clean Architecture per the constitution's Recommended Architecture section, mapped 1:1 onto this spec's 4 tabs collapsed into 3 feature modules (Overview and Envelopes share the `envelopes` feature since both operate on the same Envelope/AllocationEvent domain; Spending and Account are their own features). This is the first feature to populate `core/database/`, `core/sync/`, `core/router/`, and `core/auth/`, which is expected — the existing scaffold only had a connectivity smoke-test screen and no real data or navigation layer yet.

## Complexity Tracking

*No violations — table intentionally empty.*
