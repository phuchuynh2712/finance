---

description: "Task list template for feature implementation"
---

# Tasks: Budget Envelopes

**Input**: Design documents from `E:\Study\finance\specs\20260725-budget-envelopes\`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/schema.sql, quickstart.md

**Tests**: The constitution (Principle II) mandates tests ship in the same PR as the behavior they cover, with domain-layer (`lib/**/domain/`) line coverage ≥80%. Test tasks are therefore included and ordered before their corresponding implementation tasks within each phase, per the constitution's Testing Standards — not merely because the spec requested TDD.

**Organization**: Tasks are grouped by user story (US1 Allocate Income P1, US2 Spending+Coverage P1, US3 Configure Envelopes P2, US4 Overview+Account P3) to enable independent implementation and testing of each story, per spec.md's priority order.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4)
- Exact file paths are included in every task description

## Path Conventions

Existing Flutter mobile-app scaffold at repository root: `lib/`, `test/`, `pubspec.yaml`, `supabase/` — per plan.md's Project Structure. This feature is the first to populate `lib/core/database/`, `lib/core/sync/`, `lib/core/router/`, `lib/core/auth/`, `lib/core/formatting/`, and `lib/features/{envelopes,expenses,account}/`.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Apply the Supabase-side schema this feature needs. No pubspec dependency changes are required — `drift`, `drift_flutter`, `sqlite3_flutter_libs`, `supabase_flutter`, `go_router`, `intl`, and `flutter_secure_storage` are already declared in `pubspec.yaml` from the project scaffold.

- [X] T001 Create a new Supabase migration via `supabase migration new budget_envelopes` (this is the first feature-specific migration in this project — `supabase/migrations/` does not yet exist) and copy the DDL from `specs/20260725-budget-envelopes/contracts/schema.sql` (5 tables, RLS policies, `envelope_balances` view) into the generated file, then apply it with `supabase db push` — migration file created at `supabase/migrations/20260726154343_budget_envelopes.sql`; `SUPABASE_DB_PASSWORD` was provided by the user via `.env` and the migration was successfully pushed and confirmed applied (`supabase migration list` shows Local/Remote both at `20260726154343`)

**Checkpoint**: Supabase project has the 5 tables, RLS policies, and reconciliation view ready to receive synced data.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST exist before any user story can be implemented or independently tested — this is the first feature in the project with real local data, real navigation, and a real auth gate (the existing scaffold only has a single connectivity-check screen with no router or database). Every user story phase below assumes this phase is complete.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T002 [P] Define the `Envelopes` Drift table in `lib/core/database/tables/envelopes_table.dart` per data-model.md's Envelope entity (name, allocation_method enum, allocation_value, balance, is_rounding_receiver, plus user_id/created_at/updated_at/deleted_at), with an index on `user_id` per constitution Principle IV ("Persisted local data access MUST be indexed for the query patterns the app actually uses")
- [X] T003 [P] Define the `AllocationEvents` Drift table in `lib/core/database/tables/allocation_events_table.dart` per data-model.md's Allocation Event entity, with an index on `user_id`
- [X] T004 [P] Define the `AllocationEventLines` Drift table in `lib/core/database/tables/allocation_event_lines_table.dart` per data-model.md's Allocation Event Line entity, with FKs to `AllocationEvents` and `Envelopes`, plus indexes on `user_id` and `envelope_id`
- [X] T005 [P] Define the `ExpenseEntries` Drift table in `lib/core/database/tables/expense_entries_table.dart` per data-model.md's Expense Entry entity, with FK to `Envelopes`, plus indexes on `user_id` and `envelope_id`
- [X] T006 [P] Define the `EnvelopeCoverages` Drift table in `lib/core/database/tables/envelope_coverages_table.dart` per data-model.md's Envelope Coverage entity, with FKs to `ExpenseEntries` (cascade delete per FR-018a) and `Envelopes` (source + covering), plus indexes on `user_id`, `source_envelope_id`, and `covering_envelope_id` — added `@ReferenceName` on both envelope FKs to resolve a real drift_dev build warning (duplicate reverse-reference name), not anticipated in the original task text
- [X] T007 [P] Define the `SyncOutbox` Drift table in `lib/core/sync/sync_outbox_table.dart` per data-model.md's Sync Outbox entity, with a partial index on `synced_at` (`WHERE synced_at IS NULL`) to support the drain worker's (T012) repeated query for undrained rows, per constitution Principle IV — the `table_name` field from data-model.md is named `entityTable` in Dart since `tableName` collides with Drift's own `Table.tableName` member
- [X] T008 Create `lib/core/database/app_database.dart` wiring all 6 tables (T002-T007) into a Drift `AppDatabase`, then run `dart run build_runner build --delete-conflicting-outputs` to generate `app_database.g.dart` (depends on T002-T007) — includes `PRAGMA foreign_keys = ON` in `beforeOpen` (required by Drift/SQLite for FK constraints to actually be enforced)
- [X] T009 [P] Create `lib/core/formatting/currency_formatter.dart` — single shared VND-aware currency formatter via `intl`, per constitution Principle III ("never ad hoc string interpolation" for financial figures)
- [X] T010 [P] Create `lib/core/auth/auth_repository.dart` wrapping Supabase Auth: sign in/out (email+password per research.md §5), change password, update avatar
- [X] T011 [P] Create `lib/core/auth/auth_state_provider.dart` — Riverpod `StreamProvider` over Supabase's `onAuthStateChange`, exposing signed-in/signed-out state to the router guard and feature controllers (depends on T010)
- [X] T012 Create `lib/core/sync/sync_worker.dart` — background outbox-drain worker (connectivity-triggered + periodic drain, exponential backoff on failure per research.md §7), **plus** a periodic reconciliation check per research.md §2: compare each envelope's local materialized `balance` against the Supabase `envelope_balances` view and surface a reconciliation warning (not a silent overwrite) if they diverge (depends on T008) — **PARTIAL scheduling scope**: implemented as periodic-polling only (`Timer.periodic`, default 30s), not connectivity-change-triggered — no connectivity-detection package exists in this project's dependencies yet, and research.md §7 explicitly allows minimal v1 scheduling ("this refinement can iterate later without changing the write-path contract"); the transactional outbox write path itself is complete and correct. Reconciliation warnings are exposed via a `Stream<ReconciliationWarning>` with no UI subscriber yet (none of the consuming screens exist until later phases)
- [X] T013 [P] Create `lib/features/account/presentation/sign_in_screen.dart` — minimal email/password sign-in form. This is built in Foundational (not deferred to US4) because the router's auth guard (T014) needs a concrete redirect target before ANY tab — including US1's — can be reached during independent testing (depends on T010)
- [X] T014 Create `lib/core/router/app_router.dart` — `StatefulShellRoute.indexedStack` with 4 branches (Overview, Spending, Envelopes, Account per FR-023, Overview first/default) and a top-level `redirect` callback using T011's auth state to send unauthenticated users to T013's sign-in route (FR-025) (depends on T011, T013) — the auth-redirect decision is factored into a standalone pure function (`computeAuthRedirect`) specifically so T017 can unit-test it without constructing a real `GoRouterState`; the 3 tabs without a real screen yet (Spending, Envelopes, Account) render a temporary `_ComingSoonScreen` placeholder, swapped for the real screen by T040/T045/T050 respectively
- [X] T015 Add l10n keys for the 4 tab labels and sign-in screen strings to `lib/core/l10n/app_vi.arb` (primary) and `lib/core/l10n/app_en.arb` (secondary), both in the same change per constitution Principle III (depends on T013, T014)
- [X] T016 Update `lib/main.dart` to use `MaterialApp.router` with T014's `app_router.dart`, replacing the current `home: const ConnectionTestScreen()` setup — keep the existing `theme`/`darkTheme`/`themeMode`/`locale`/`supportedLocales`/`localizationsDelegates` configuration untouched (depends on T014) — additionally removed the now-orphaned `connection_test` feature (module + its 4 now-unreferenced l10n keys) in the same change, since main.dart was its only consumer and the constitution (Principle I) prohibits merging dead code; verified via full-project `flutter analyze` (clean) and `flutter test` (all pre-existing tests, including `test/widget_test.dart` and `test/unit/core/theme/app_theme_test.dart`, still pass unaffected)
- [X] T017 [P] Unit test for the router's auth-redirect logic in `test/unit/core/router/app_router_test.dart` — given signed-in/signed-out/loading auth states, confirm the redirect callback returns the correct route (or `null` to allow navigation) (depends on T014)

**Checkpoint**: The app has a real local database, a working 4-tab navigation shell, and a functioning (if UI-minimal) auth gate. Every user story below can now be built and independently tested against this foundation.

---

## Phase 3: User Story 1 - Allocate Income Into Envelopes (Priority: P1) 🎯 MVP

**Goal**: A user can enter an income amount, review a correct allocation preview across their configured envelopes (fixed + percentage, independently computed, rounding-remainder and over-allocation handled deterministically), confirm it, and see each envelope's balance update additively.

**Independent Test**: With at least one percentage-based and one fixed-amount envelope already seeded directly via the repository (envelope CRUD UI is US3, not required here), open the Overview tab, start a "Plan" action, enter an income amount, review the calculated per-envelope breakdown, confirm, and verify each envelope's balance increased by the correct amount.

### Tests for User Story 1

> Write this test FIRST, ensure it FAILS before implementation (no `compute_allocation_preview` exists yet)

- [ ] T018 [P] [US1] Unit test for the allocation calculation in `test/unit/features/envelopes/domain/compute_allocation_preview_test.dart` — covers: fixed and percentage allocations computed independently against full income (FR-004/FR-005 per Clarifications), round-half-up + leftover-to-receiver such that the sum always exactly equals income entered when a receiver is flagged (FR-006/FR-007, SC-002), **blocking confirmation when a nonzero leftover exists but no envelope is flagged as the rounding-remainder receiver (FR-013 — distinct from over-allocation below: here income is left unclaimed, not exceeded)**, over-allocation detection when combined total exceeds income (FR-011a), single-envelope negative-balance detection (FR-011), and rejection of zero/negative income (FR-029)

### Implementation for User Story 1

- [ ] T019 [P] [US1] Create the `Envelope` domain entity in `lib/features/envelopes/domain/envelope.dart`
- [ ] T020 [P] [US1] Create the `AllocationEvent` domain entity in `lib/features/envelopes/domain/allocation_event.dart`
- [ ] T021 [P] [US1] Create the `AllocationEventLine` domain entity in `lib/features/envelopes/domain/allocation_event_line.dart`
- [ ] T022 [US1] Create the `EnvelopeRepository` interface in `lib/features/envelopes/domain/envelope_repository.dart` (CRUD + balance read/update signatures) (depends on T019)
- [ ] T023 [US1] Create the `AllocationRepository` interface in `lib/features/envelopes/domain/allocation_repository.dart` (confirm-event signature; no update/delete — events are immutable per spec Key Entities) (depends on T020, T021)
- [ ] T024 [US1] Implement the `compute_allocation_preview` pure use case in `lib/features/envelopes/domain/compute_allocation_preview.dart` per research.md §1's exact algorithm, including its no-receiver-flagged blocking branch (FR-013) as distinct from the over-allocation branch (FR-011a) (depends on T019-T021; makes T018 pass)
- [ ] T025 [US1] Implement `EnvelopeRepositoryImpl` (Drift-backed) in `lib/features/envelopes/data/envelope_repository_impl.dart` — every write (create/edit/delete, and the balance updates used by US1/US2) commits to Drift and appends a `sync_outbox` row in the same transaction, per the constitution's Offline-First mandate (depends on T022, T008)
- [ ] T026 [US1] Implement `AllocationRepositoryImpl` in `lib/features/envelopes/data/allocation_repository_impl.dart` — writes the event row, its per-envelope lines, each affected envelope's updated balance, and a `sync_outbox` row, all in one Drift transaction (depends on T023, T008)
- [ ] T027 [US1] Create the Plan flow controller (Riverpod) and `lib/features/envelopes/presentation/plan_screen.dart` — income entry → live preview via T024 → confirm via T026, with blocking UI states for the over-allocation (FR-011a) and negative-balance (FR-011) warnings and FR-012's suggested adjustment (depends on T024, T026)
- [ ] T028 [US1] Create `lib/features/envelopes/presentation/overview_screen.dart` — envelope list with current balances, plus a "Plan" action that opens T027's `plan_screen.dart` (depends on T025, T027)
- [ ] T029 [US1] Register `overview_screen.dart` as the Overview tab branch's screen in `app_router.dart` (depends on T014, T028)
- [ ] T030 [P] [US1] Add l10n keys for the Plan flow and Overview screen strings to `app_vi.arb`/`app_en.arb` (depends on T027, T028)
- [ ] T031 [P] [US1] Widget test for the Plan preview flow in `test/widget/features/envelopes/plan_screen_test.dart` — covers preview rendering, confirm action, and the over-allocation/negative-balance blocking states (depends on T027)

**Checkpoint**: User Story 1 is independently functional — a user with seeded envelope data can allocate income and see correct, additive balance updates, satisfying all of US1's acceptance scenarios.

---

## Phase 4: User Story 2 - Record Spending With Inline Overspend Coverage (Priority: P1)

**Goal**: A user can log an expense against an envelope, have its balance decrease correctly, and — if the expense would overspend that envelope — resolve the shortfall inline via a covering-envelope prompt before the entry saves. Previously saved expenses can be edited or deleted with correct balance/coverage reversal.

**Independent Test**: With an envelope holding a known balance (from US1's flow or seeded data), add a manual expense entry for an amount less than the balance and confirm the balance decreases correctly; add an expense exceeding the balance and confirm the inline covering-envelope prompt appears and both envelopes update correctly after resolution; edit and delete a saved expense and confirm balances/coverage reverse correctly.

### Tests for User Story 2

> Write this test FIRST, ensure it FAILS before implementation

- [ ] T032 [P] [US2] Unit test for overspend detection and reversal logic in `test/unit/features/expenses/domain/compute_overspend_test.dart` — covers: overspend detection triggering the covering-envelope requirement (FR-016), the no-other-envelope skip case (FR-016's Clarifications addendum), and edit/delete reversal semantics including re-triggering overspend on an upward edit (FR-018a)

### Implementation for User Story 2

- [ ] T033 [P] [US2] Create the `ExpenseEntry` domain entity in `lib/features/expenses/domain/expense_entry.dart`
- [ ] T034 [P] [US2] Create the `EnvelopeCoverage` domain entity in `lib/features/expenses/domain/envelope_coverage.dart`
- [ ] T035 [US2] Create the `ExpenseRepository` interface in `lib/features/expenses/domain/expense_repository.dart` (create/edit/delete signatures) (depends on T033, T034)
- [ ] T036 [US2] Implement the `compute_overspend` pure use case in `lib/features/expenses/domain/compute_overspend.dart` (depends on T033, T034; makes T032 pass)
- [ ] T037 [US2] Implement `ExpenseRepositoryImpl` in `lib/features/expenses/data/expense_repository_impl.dart` — record/edit/delete each in one Drift transaction with a `sync_outbox` row; edit/delete first reverse the original entry's envelope-balance and coverage effects before (for edits) reapplying the new values, per FR-018a; reads/writes envelope balances through `EnvelopeRepository` (US1's public domain interface, not its `data/` internals) (depends on T035, T022, T008)
- [ ] T038 [US2] Create `lib/features/expenses/presentation/expense_form_screen.dart` — amount/envelope/date/note entry, with the inline covering-envelope prompt (FR-016/FR-017/FR-018) and the edit-mode re-trigger path (FR-018a) (depends on T036, T037)
- [ ] T039 [US2] Create `lib/features/expenses/presentation/spending_screen.dart` — expense list (with edit/delete entry points into T038) plus an "Add expense" action; when the user has zero envelopes (queried via `EnvelopeRepository`), the "Add expense" action is disabled/redirected to the Envelopes tab with guidance to create one first, instead of opening `expense_form_screen.dart` (FR-030) (depends on T037, T038, T022)
- [ ] T040 [US2] Register `spending_screen.dart` as the Spending tab branch's screen in `app_router.dart` (depends on T014, T039)
- [ ] T041 [P] [US2] Add l10n keys for expense entry and covering-envelope prompt strings to `app_vi.arb`/`app_en.arb` (depends on T038, T039)
- [ ] T042 [P] [US2] Widget test for the expense form and covering-envelope prompt in `test/widget/features/expenses/expense_form_screen_test.dart` — covers a routine entry, an overspending entry triggering the prompt, cancel-out-of-prompt, edit/delete of a saved entry, and (against `spending_screen.dart`) that "Add expense" is disabled/redirects when zero envelopes exist (FR-030) (depends on T038, T039)

**Checkpoint**: User Stories 1 AND 2 both work independently and together form the core envelope-budgeting loop (allocate → spend → cover) — the minimum viable, end-to-end usable product.

---

## Phase 5: User Story 3 - Configure Envelopes (Priority: P2)

**Goal**: A user can create, edit, and delete their own envelopes and designate the rounding-remainder receiver, without relying on seeded/directly-inserted data.

**Independent Test**: From the Envelopes tab, create a new envelope with a name and percentage allocation, edit an existing envelope's fixed amount, delete an unused envelope, and flag one envelope as the rounding-remainder receiver — verify each change is reflected immediately and persists across app restarts.

### Implementation for User Story 3

- [ ] T043 [US3] Create `lib/features/envelopes/presentation/envelope_form_screen.dart` — create/edit envelope (name, allocation method + value, rounding-receiver toggle) (depends on T022, T025)
- [ ] T044 [US3] Create `lib/features/envelopes/presentation/envelopes_screen.dart` — envelope list with create/edit/delete actions, the non-zero-balance delete warning (FR-027), and the rounding-receiver reassignment-before-delete flow (FR-028) (depends on T025, T043)
- [ ] T045 [US3] Register `envelopes_screen.dart` as the Envelopes tab branch's screen in `app_router.dart` (depends on T014, T044)
- [ ] T046 [P] [US3] Add l10n keys for envelope CRUD and rounding-receiver strings to `app_vi.arb`/`app_en.arb` (depends on T043, T044)
- [ ] T047 [P] [US3] Widget test for the Envelopes CRUD screen in `test/widget/features/envelopes/envelopes_screen_test.dart` — covers create, edit, delete-with-warning, rounding-receiver mutual exclusivity (FR-002), and reassignment-on-delete (FR-028) (depends on T044)

**Checkpoint**: User Stories 1-3 together give a fully self-service MVP — users no longer need seeded data to exercise the app end to end.

---

## Phase 6: User Story 4 - View Envelope Overview and Manage Account (Priority: P3)

**Goal**: A user sees every envelope's balance at a glance on Overview with overspent ones clearly flagged, and can manage their avatar/password from the Account tab.

**Independent Test**: With a mix of positive and negative (overspent) envelope balances, open the Overview tab and verify all envelopes are listed with correct balances and that negative ones are visually flagged; separately, verify the Account tab supports avatar update and password change.

### Implementation for User Story 4

- [ ] T048 [US4] Enhance `overview_screen.dart` with visual negative-balance flagging (FR-020, SC-005 — identifiable within 5 seconds) (depends on T028)
- [ ] T049 [US4] Create `lib/features/account/presentation/account_screen.dart` — avatar update, change password, and sign-out, built on T010's `auth_repository.dart` (depends on T010)
- [ ] T050 [US4] Register `account_screen.dart` as the Account tab branch's screen in `app_router.dart` (depends on T014, T049)
- [ ] T051 [P] [US4] Add l10n keys for Account screen and negative-balance flagging strings to `app_vi.arb`/`app_en.arb` (depends on T048, T049)
- [ ] T052 [P] [US4] Widget test for Overview's negative-balance flagging in `test/widget/features/envelopes/overview_screen_test.dart` (depends on T048)
- [ ] T053 [P] [US4] Widget test for the Account screen (avatar/password update, sign-out) in `test/widget/features/account/account_screen_test.dart` (depends on T049)

**Checkpoint**: All four user stories are independently functional — the full spec is covered.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final validation spanning all four stories together, plus the constitution's project-wide gates.

- [ ] T054 [P] Integration test for the full allocate → spend → overspend-coverage flow in `test/integration/allocate_spend_cover_flow_test.dart`, run against an in-memory Drift database per plan.md's Testing section — explicitly includes confirming **two** allocation events for the same envelopes and asserting balances increased additively rather than being reset (FR-008/FR-009), and that each event's per-envelope breakdown is persisted and retrievable via `AllocationEventLine` rows (FR-010)
- [ ] T055 [P] Verify unit test line coverage for `lib/features/envelopes/domain/` and `lib/features/expenses/domain/` is ≥80% (constitution Principle II gate) via `flutter test --coverage` and inspecting `coverage/lcov.info`
- [ ] T056 [P] Manually verify Supabase RLS policies applied in T001: confirm a second test account cannot read or write another user's envelopes/allocation events/expense entries/coverages (constitution Security section gate)
- [ ] T057 Run `flutter analyze` across all new/changed files from this feature — zero errors/warnings (constitution Principle I)
- [ ] T058 Run `dart format` on all new/modified Dart files
- [ ] T059 Execute the full `quickstart.md` verification walkthrough end-to-end (all 4 user stories, offline behavior, automated-coverage checkpoint) as a final combined check

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately.
- **Foundational (Phase 2)**: BLOCKS all user stories, but is **not** itself blocked by Setup except for one task: only T012 (the sync worker, which pushes to the live Supabase schema) depends on T001. T002-T011, T013-T014, and T016-T017 are pure local Drift/UI work and can start immediately in parallel with T001 — don't sequence the whole phase behind the migration task. T002-T007 (table definitions) can run in parallel; T008 depends on all of them; T009-T013 can run in parallel with each other and with T008; T014 depends on T011 and T013; T015-T017 depend on T014.
- **User Story 1 (Phase 3)**: Depends on Foundational (Phase 2) completion. Independent of US2/US3/US4.
- **User Story 2 (Phase 4)**: Depends on Foundational, and on US1's `EnvelopeRepository` interface (T022) existing to read/update envelope balances — but not on US1's UI. Independent of US3/US4.
- **User Story 3 (Phase 5)**: Depends on Foundational, and on US1's `Envelope` domain/data layer (T022, T025) — but not on US1's Plan UI. Independent of US2/US4.
- **User Story 4 (Phase 6)**: Depends on Foundational (T010 for auth, T028 for Overview to enhance) — the account half is independent of US1-US3; the Overview-flagging half depends on T028 (US1) existing.
- **Polish (Phase 7)**: Depends on US1-US3 being complete (T054's integration test exercises all three); T057-T059 depend on all prior phases.

### User Story Dependencies

- **User Story 1 (P1)**: No dependency on other stories — this is the MVP starting point.
- **User Story 2 (P1)**: Reads/writes envelope balances through US1's `EnvelopeRepository` domain interface (not its UI or data internals) — buildable/testable independently once that interface exists.
- **User Story 3 (P2)**: Builds UI on top of US1's `Envelope` domain/data layer — buildable/testable independently once that layer exists. Per spec.md's own rationale, US1/US2 can be demonstrated with seeded envelope data before US3's CRUD UI exists.
- **User Story 4 (P3)**: Account management is fully independent; Overview flagging is a small enhancement to US1's existing screen.

### Parallel Opportunities

- T002-T007 (Foundational table definitions) can all run in parallel — different files, no dependencies on each other.
- T009, T010, T013 (Foundational) can run in parallel with each other and with the T002-T008 database chain.
- Within US1: T019-T021 (entities) in parallel; T030 (l10n) and T031 (widget test) in parallel with each other once their dependencies land.
- Within US2: T033-T034 (entities) in parallel; T041/T042 in parallel.
- US2 and US3 can be worked on in parallel by different developers once Foundational + US1's T022/T025 exist, since they touch disjoint files (`features/expenses/` vs. `features/envelopes/presentation/envelope*_screen.dart`).
- T054-T056 (Polish) can run in parallel with each other.

---

## Parallel Example: Foundational phase

```bash
# These can all start immediately (in parallel with each other AND with Setup's
# T001 — only T012's sync worker actually needs the live Supabase schema):
Task: "Define Envelopes Drift table in lib/core/database/tables/envelopes_table.dart (T002)"
Task: "Define AllocationEvents Drift table in lib/core/database/tables/allocation_events_table.dart (T003)"
Task: "Define AllocationEventLines Drift table in lib/core/database/tables/allocation_event_lines_table.dart (T004)"
Task: "Define ExpenseEntries Drift table in lib/core/database/tables/expense_entries_table.dart (T005)"
Task: "Define EnvelopeCoverages Drift table in lib/core/database/tables/envelope_coverages_table.dart (T006)"
Task: "Define SyncOutbox Drift table in lib/core/sync/sync_outbox_table.dart (T007)"
Task: "Create currency_formatter.dart (T009)"
Task: "Create auth_repository.dart (T010)"
Task: "Create sign_in_screen.dart (T013)"
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 2 Only)

1. Complete Phase 1: Setup (T001)
2. Complete Phase 2: Foundational (T002-T017) — CRITICAL, blocks everything else
3. Complete Phase 3: User Story 1 (T018-T031)
4. Complete Phase 4: User Story 2 (T032-T042)
5. **STOP and VALIDATE**: With seeded envelope data, confirm the full allocate → spend → overspend-coverage loop works end to end
6. This is the smallest shippable increment that delivers the envelope-budgeting method's core value — deploy/demo if ready

### Incremental Delivery

1. Setup + Foundational → local DB, navigation shell, and auth gate ready
2. Add User Story 1 → Test independently → the app can allocate income (seeded envelopes)
3. Add User Story 2 → Test independently → Deploy/Demo (MVP — full allocate/spend/cover loop)
4. Add User Story 3 → Test independently → Deploy/Demo (fully self-service, no seeded data needed)
5. Add User Story 4 → Test independently → Deploy/Demo (overview flagging + account management complete the spec)
6. Phase 7 Polish → final combined validation across all four stories plus constitution gates

### Parallel Team Strategy

With multiple developers, once Foundational is done:

1. Developer A: User Story 1 (unblocks B and C below)
2. Once US1's T022/T025 land: Developer B takes User Story 2, Developer C takes User Story 3, in parallel — disjoint files
3. Developer D: User Story 4's Account half (independent from the start); the Overview-flagging half waits on US1's T028
4. All four stories integrate without touching each other's files, per the feature-first architecture

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- This feature carries an unusually large Foundational phase (T002-T017) because it is the first in the project to use Drift, `go_router`, and Supabase Auth for anything real — every subsequent feature in this codebase will have a much smaller Foundational phase, since this infrastructure will already exist
- Tests are written before their corresponding implementation task within each phase (T018 before T019-T031, T032 before T033-T042) per the constitution's Testing Standards, and MUST fail before that implementation exists
- All FR-/SC- references are sourced from spec.md; all technical decisions referenced (research.md §N) require no re-reading to execute — the rationale is summarized inline where it affects a task's acceptance criteria
- Commit after each task or logical group
- Stop at any checkpoint to validate a story independently
