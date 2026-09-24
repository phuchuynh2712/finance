# Implementation Plan: Transaction History

**Branch**: `20260924-071637-transaction-history` | **Date**: 2026-09-24 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/20260924-071637-transaction-history/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Replace the Spending hub's transaction-history placeholder with a localized,
offline-first monthly transaction-history screen. The feature adds immutable
display snapshots to financial transactions, backfills existing rows, preserves
outbox synchronization, and exposes a reactive application-facing history
read model to the Spending feature. The screen supports month navigation,
monthly expense totals, dynamic group and Income filters, date-grouped rows,
and loading, empty, and retry states in the existing light and dark themes.

## Technical Context

**Language/Version**: Dart 3.11 / Flutter (existing project)

**Primary Dependencies**: Flutter Material, flutter_riverpod, Drift/SQLite,
GoRouter, intl, lucide_icons, existing localization/theme/formatting helpers.
No new runtime package is required.

**Storage**: Existing local Drift/SQLite database, sync outbox, and Supabase
`financial_transactions` table. Both local and remote schemas gain immutable
display snapshot fields plus required sync timestamps/tombstone metadata through
versioned migrations.

**Testing**: `flutter analyze`, `dart format --output=none --set-exit-if-changed`,
focused unit/widget/integration tests, then `flutter test`.

**Target Platform**: Existing Android and iOS Flutter application.

**Project Type**: Feature-first mobile application.

**Performance Goals**: Maintain 60 fps scrolling; filter a selected month of
at least 100 rows in under 1 second; use a lazy list and a user/month-indexed
database query.

**Constraints**: Offline-first local reads, atomic transaction-plus-outbox
writes, Vietnamese and English localization, established light/dark design
tokens, minimum 48dp interactive targets, no raw financial values in logs,
and no direct presentation dependency on another feature's internals.

**Scale/Scope**: One new full-screen route launched from Spending; transaction
snapshot migration, history read model, state/UI, route, localization, and
focused regression coverage. The Report tab and search behavior remain out of
scope.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

- **Principle I — Code Quality: PASS.** The history query, snapshot/backfill,
  and filter transformation are outside widgets and exposed through a
  narrow application-facing facade. Presentation remains state/rendering only.
- **Principle II — Testing Standards: PASS with required coverage.** Add
  unit tests for migration/backfill, snapshot persistence, history grouping and
  filters; widget tests for the full screen; and an integration path from
  recorded income/expense to history. Existing domain/data coverage must not
  fall below 80%.
- **Principle III — UX Consistency: PASS.** Use existing semantic colors,
  CurrencyFormatter, ARB localization, Lexend theme, shared empty/loading/error
  patterns, and 48dp controls. Both themes receive widget/golden or manual
  visual verification.
- **Principle IV — Performance: PASS.** The query is constrained by user and
  month and backed by the existing `(user_id, occurred_at)` index; rendering
  uses slivers or `ListView.builder` with small scoped Riverpod rebuilds.
- **Clean Architecture: PASS.** The Spending presentation layer receives a
  history read contract through its application facade rather than importing
  `expense_control` data or presentation internals. Database and sync work
  stays in the owning data/composition boundary.
- **Offline-first and Security: PASS.** Local history is immediately readable;
  every created/backfilled snapshot is included in the existing outbox contract
  and mirrored by a Supabase migration with existing RLS retained. No sensitive
  values are logged.

**Post-design re-check**: PASS. Research and contracts introduce no new
packages, service, network API, or unapproved architecture exception.

## Project Structure

### Documentation (this feature)

```text
specs/20260924-071637-transaction-history/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)
```text
lib/
├── core/
│   ├── database/
│   │   ├── app_database.dart                     # schema v6 and backfill
│   │   └── tables/financial_transactions_table.dart
│   ├── di/expense_dependencies.dart              # repository/facade wiring
│   ├── l10n/app_{vi,en}.arb                      # history strings
│   └── router/app_router.dart                    # full-screen history route
├── features/
│   ├── expense_control/
│   │   ├── data/expense_control_repository_impl.dart
│   │   ├── domain/expense_control_repository.dart
│   │   └── domain/transaction_history_record.dart # owner-domain read record
│   └── expenses/
│       ├── application/
│       │   ├── expense_control_gateway.dart      # public history read facade
│       │   └── transaction_history.dart          # Spending view mapping/state
│       └── presentation/
│           ├── spending_screen.dart              # route entry
│           ├── transaction_history_providers.dart
│           └── transaction_history_screen.dart
├── supabase/migrations/                           # snapshot schema migration
test/
├── unit/features/expense_control/                 # snapshot + query behavior
├── unit/features/expenses/application/            # grouping/filter state
├── widget/features/expenses/                      # screen interaction/states
└── integration/                                   # record-to-history flow
```

**Structure Decision**: Retain the existing Flutter feature-first layout.
`expense_control` owns transaction persistence, owner-domain history records,
and writes; `expenses` owns the history experience and maps those records to
its view state through an explicit application facade. No new cross-feature
presentation import or generic UI abstraction is needed.

## Phase 0: Research Summary

Research is recorded in [research.md](./research.md). The existing
`financial_transactions` table is already the single history source and has
the required month-read index, but lacks immutable labels and required sync
timestamps/tombstone metadata. Snapshot columns, sync metadata, atomic
write-path population, cumulative local migration, remote migration, and
outbox payload updates are required. The history screen uses a thin application
facade and localized view mapping rather than exposing Drift rows.

## Phase 1: Design Summary

- [data-model.md](./data-model.md) defines persistent snapshots, migration
  rules, read-model grouping, and filter state.
- [contracts/transaction-history-ui.md](./contracts/transaction-history-ui.md)
  defines the internal application/UI contract and state outcomes.
- [contracts/transaction-history-sync.md](./contracts/transaction-history-sync.md)
  defines local/remote snapshot parity and outbox payload requirements.
- [quickstart.md](./quickstart.md) lists migration, data, navigation, visual,
  formatting, analysis, and test verification steps.

## Complexity Tracking

No constitution violations or complexity exceptions are required.
