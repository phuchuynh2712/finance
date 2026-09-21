# Implementation Plan: Expense Transaction Recording

**Branch**: `20260921-202232-expense-transaction` | **Date**: 2026-09-21 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/20260921-202232-expense-transaction/spec.md`

## Summary

Replace the "Chi tiêu" button's placeholder with a real screen that records expense transactions against a leaf budget item — atomically decrementing that item's `balance` and inserting one row into a new `financial_transactions` table. The same table is extended to also receive income-allocation history (one row per non-zero delta from the existing `applyIncomeAllocation`, atomic with its existing balance increments), so a future Report feature has one consistent, queryable source for both directions. Technical approach: one new Drift table mirroring `expense_control_items`' existing conventions exactly (no new patterns), one new repository method (`recordExpense`) following the codebase's established atomic-transaction-plus-outbox shape, and a screen reusing `ExpenseControlPlanService`'s existing (now-public) leaf-flattening logic for its item picker.

## Technical Context

**Language/Version**: Dart (SDK `^3.11.0`), Flutter (stable channel, per existing project)

**Primary Dependencies**: `flutter_riverpod` (state management, existing), `drift`/`drift_flutter` (local persistence, existing), `uuid` (id generation, existing), `lucide_icons` (icon set, existing)

**Storage**: Drift (SQLite) — one new table, `financial_transactions`, following the exact schema/index/outbox conventions `expense_control_items` already established. Supabase mirrors it with a real Postgres FK and RLS policy, per that table's own migration precedent.

**Testing**: `flutter_test` (unit + widget), matching existing project convention

**Target Platform**: Android + iOS (existing app targets)

**Project Type**: Mobile app (Flutter, single codebase, existing feature-first + Clean Architecture layering per Constitution)

**Performance Goals**: Recording an expense end-to-end (screen open → balance visible on Thu chi) in under 15s for a typical entry (SC-001) — in practice a single Drift transaction plus a screen pop, well inside budget; no new list rendering at scale is introduced (the leaf-item picker is bounded by the user's own Kiểm soát chi tiêu setup, already small in practice).

**Constraints**: Every write (expense record, income-allocation history) MUST be atomic with its corresponding balance mutation — no partial state ever (FR-009, FR-013, SC-002, SC-004). Balance MUST be allowed to go negative (FR-010) — no validation blocks a save on that basis.

**Scale/Scope**: One new Drift table + matching Supabase table, one new repository method, one extended existing repository method (no signature change), one new screen (two tabs, one of which — "Quét hoá đơn" — is a static UI scaffold per spec.md), one changed navigation call site (`SpendingScreen`'s "Chi tiêu" button).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design below.*

- **I. Code Quality**: PASS. Business logic (the atomic balance+history write) lives in `ExpenseControlRepositoryImpl`, not in a widget's `build()`. The new screen's controller (state management for amount/picked-item/submit) is a plain, testable Riverpod notifier, following the exact pattern already used by `IncomeFormController`. `ExpenseControlPlanService._flattenLeaves` is promoted to public rather than duplicated — no new parallel implementation of "what is a leaf, in what order" is introduced.
- **II. Testing Standards**: PASS (planned). Unit tests for `recordExpense` (balance decrement, history row created, atomicity under a simulated concurrent/failing write — mirroring the existing `applyIncomeAllocation` atomicity test's exact pattern) and for the extended `applyIncomeAllocation` (history rows now also asserted, per-item, sharing one timestamp). Widget tests for the "Chi tiêu" screen covering every FR (preview banner color/text, save gating, negative-balance allowance, leaf-only picker, empty-state). This feature directly touches money-math correctness (balance mutation), so the 80% domain/data coverage bar is non-negotiable here, not just aspirational.
- **III. User Experience Consistency**: PASS. Reuses the existing design-token system (`AppColors`/`AppSemanticColors`) and the existing `EmptyStateView` widget for the empty-leaf-items state, rather than inventing new components. The dark-mode preview-banner color inconsistency in the reference mockup is explicitly resolved using the app's own existing dark-mode danger/success token pair (research.md Decision 11), not copied literally — consistent with how the prior Profile-settings feature resolved an analogous mockup artifact. Currency formatting uses the existing shared `CurrencyFormatter`, never ad hoc string interpolation.
- **IV. Performance Requirements**: PASS. No new heavy computation or large-list rendering. The leaf-item picker is a horizontally scrollable list bounded by the user's own budget-item count (already small by construction — Kiểm soát chi tiêu is manually curated). The atomic Drift transaction is the same shape (and therefore the same performance profile) as the already-shipped `applyIncomeAllocation`.
- **Offline-First Data & Sync**: PASS. `financial_transactions` is relational, user-owned financial data — squarely inside Drift's mandate per the Constitution's Offline-First section (not the key-value-store exception used by the Profile-settings feature). Every write goes through the existing outbox pattern (`_appendOutbox`, one row per changed table per write) inside the same local transaction as the actual data change, matching every other write in `ExpenseControlRepositoryImpl` today. No Supabase Realtime/conflict-resolution changes are needed — this feature only adds inserts (no updates/deletes to `financial_transactions` are in scope, per spec.md's Out of Scope section), so last-write-wins conflict resolution and reconciliation-against-server-authoritative-balance (already documented as a known, accepted gap since the spending-balance-hub feature) are unaffected by this feature specifically.
- **Security**: PASS. New Supabase table gets a real RLS policy (`auth.uid() = user_id`, matching `expense_control_items`' own policy exactly) — no table ships without one, per the Constitution's explicit "a table without an RLS policy MUST NOT be deployed" rule. No new secrets, tokens, or externally-exposed surface. No financial values are logged (this feature introduces no new logging).

No violations requiring Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/20260921-202232-expense-transaction/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md         # Phase 1 output
├── quickstart.md         # Phase 1 output
├── contracts/
│   └── expense_transaction_ui_state.md
├── reference/             # Preserved design handoff (README.md, chi-tieu-spec.md,
│                           # icons.json, theme-tokens.json, screen-light.png,
│                           # screen-dark.png) — copied from
│                           # E:\Study\design\chi-tieu-package per the original request
└── tasks.md               # Phase 2 output (/speckit-tasks — not created by /speckit-plan)
```

### Source Code (repository root)

```text
lib/
├── core/
│   └── database/
│       ├── app_database.dart                          # MODIFIED — schemaVersion 4→5,
│       │                                                #   new onUpgrade block, register
│       │                                                #   FinancialTransactions table
│       ├── app_database.g.dart                         # REGENERATED (build_runner)
│       └── tables/
│           └── financial_transactions_table.dart        # NEW — FinancialTransactions table +
│                                                          #   TransactionDirection enum
├── features/
│   └── expense_control/
│       ├── domain/
│       │   ├── expense_control_repository.dart          # MODIFIED — add recordExpense()
│       │   │                                            #   to the interface
│       │   └── expense_control_plan_service.dart        # MODIFIED — _flattenLeaves → public
│       └── data/
│           └── expense_control_repository_impl.dart     # MODIFIED — implement recordExpense();
│                                                          #   extend applyIncomeAllocation's
│                                                          #   existing transaction with history
│                                                          #   inserts
└── features/
    └── expenses/
        └── presentation/
            ├── expense_screen.dart                       # NEW — "Chi tiêu" screen (both tabs)
            ├── expense_providers.dart                    # NEW — controller/state for the
            │                                              #   screen (mirrors income_providers.dart)
            └── spending_screen.dart                      # MODIFIED — "Chi tiêu" button now
                                                            #   Navigator.push's ExpenseScreen
                                                            #   instead of _openPlaceholder

supabase/migrations/
└── <timestamp>_financial_transactions.sql                # NEW — table + FK + RLS + indexes

test/
├── unit/
│   └── features/expense_control/
│       ├── expense_control_repository_impl_test.dart     # EXTENDED — recordExpense tests +
│       │                                                  #   applyIncomeAllocation history tests
│       └── expense_control_plan_service_test.dart        # EXTENDED — public leaf-flattening API
├── widget/
│   └── features/expenses/
│       ├── expense_screen_test.dart                       # NEW
│       └── spending_screen_test.dart                       # EXTENDED — "Chi tiêu" navigates to
│                                                             #   the real screen, not a placeholder
└── integration/
    └── schema_v4_to_v5_migration_test.dart                 # NEW — mirrors the existing
                                                              #   schema_v3_to_v4 regression test's
                                                              #   cumulative-<=-migration coverage
```

**Structure Decision**: Single Flutter project, existing feature-first + Clean Architecture layering (Constitution's Recommended Architecture). The new table and repository method live in `expense_control/` (the feature that already owns `expense_control_items` and `balance` mutation) rather than a new `transactions/` feature directory — this mirrors how `applyIncomeAllocation` (income-side balance mutation) already lives in the same place despite being conceptually "income," not "expense control": the mutation target (`expense_control_items.balance`) is what determines ownership, not the direction of money flow. The new screen itself lives in `features/expenses/` alongside `income_screen.dart`, consistent with how that screen is already organized relative to `SpendingScreen`.

## Complexity Tracking

*No Constitution Check violations — table intentionally empty.*
