---

description: "Task list for Secure Storage Risk Decision & Routing Cleanup"
---

# Tasks: Secure Storage Risk Decision & Routing Cleanup

**Input**: Design documents from `/specs/20260925-051953-secure-storage-routing-cleanup/`
**Prerequisites**: plan.md, spec.md, research.md

## Format: `[ID] [P?] [Story] Description`

---

## Phase 1: User Story 1 - Secure storage risk decision (Priority: P1) 🎯 Must finish

**Goal**: An explicit, reviewed decision recorded in the constitution.

- [X] T001 [US1] Amend `.specify/memory/constitution.md`'s Security
  section: add a bullet stating the Web session-token storage risk
  (`flutter_secure_storage`'s experimental WebCrypto+`localStorage`
  backend) is **accepted**, conditional on HSTS at the eventual Web host,
  with the reasoning from research.md Decision 1 (session token, not raw
  financial data; revocable; smaller Flutter-Web XSS surface). Bump the
  constitution's version (PATCH — clarification/decision, no principle
  redefined) and update its Sync Impact Report per Governance's own rule.
- [X] T002 [US1] Cross-reference this decision from
  `web-platform-enablement/spec.md`'s Out-of-Scope item 2 (add one
  sentence: "resolved — see secure-storage-routing-cleanup") so the
  backlog doesn't still read as open once this ships.

**Checkpoint**: constitution states the decision; no code changed.

---

## Phase 2: User Story 2 - Routing cleanup (Priority: P2)

**Goal**: Convert `Navigator.push` call sites to nested `go_router`
routes, tiered by complexity (research.md Decision 3) so the story is
safely stoppable after any tier (FR-008).

### Tier A — parameterless (do first)

- [X] T003 [P] [US2] Add `incomeRoute`/`expenseRoute` builder functions to
  `lib/features/expenses/expenses_routes.dart` (return
  `const IncomeScreen()` / `const ExpenseScreen()`).
- [X] T004 [P] [US2] Add a `transactionHistoryRoute` builder function to
  the same file (returns `const TransactionHistoryScreen()`, unfiltered).
- [X] T005 [US2] In `lib/core/router/app_router.dart`, nest new
  `GoRoute`s under the `/spending` branch: `income`, `expense`,
  `history` (paths relative to `/spending`), using T003/T004's builders
  (depends on T003, T004).
- [X] T006 [US2] In `lib/features/expenses/presentation/spending_screen.dart`,
  replace the 3 `Navigator.of(context).push(MaterialPageRoute(...))` calls
  (lines 52, 67, 79 — re-verify before editing) with
  `context.push('/spending/income')` etc.
- [X] T007 [US2] Nest a `history` `GoRoute` under the `/overview` branch
  (reusing T004's `transactionHistoryRoute` builder) in `app_router.dart`;
  in `overview_screen.dart`, replace the "see all" push (line 392 —
  re-verify) with `context.push('/overview/history')`.
- [X] T008 [P] [US2] Update/add widget tests for the above 4 conversions
  (`test/widget/features/expenses/spending_screen_test.dart` and
  `overview_screen_test.dart`), using a real `GoRouter` test harness per
  research.md Decision 4: assert the address changes to the expected path
  and the destination screen renders; assert back navigation returns
  correctly. **Result**: found 4 pre-existing tests asserting the real
  destination screen appears after a tap; fixed by giving each harness a
  real `GoRouter` mirroring `app_router.dart`'s actual nested-route shape
  (not a simplified placeholder route), so the existing assertions kept
  working unchanged. All 4 pass; no other test in either file regressed.

**Checkpoint**: Tier A shippable alone — Income/Expense/History screens
have real URLs; everything else (Tiers B/C) still works exactly as
before, unconverted.

### Tier B — parameterized placeholder (do if budget allows)

- [X] T009 [US2] Add a small `AccountPlaceholderFeature` enum (or
  equivalent key) plus a `placeholderRoute` builder function that maps
  the key to the right icon/l10n title/message, in
  `lib/features/account/account_routes.dart`.
- [X] T010 [US2] Nest a `placeholder/:feature` `GoRoute` under `/account`
  in `app_router.dart` (depends on T009); update `account_screen.dart`'s
  `_openPlaceholder` call sites (lines 152, 164, 176 — re-verified) to
  `context.push('/account/placeholder/$key')`. **Result**: also removed
  `account_screen.dart`'s now-dead `_openPlaceholder` helper and its
  unused `NotAvailablePlaceholderScreen` import (no dead code left
  behind, per constitution Principle I).
- [X] T011 [US2] Repeat T009's key/lookup approach (or add one more key to
  it) for `overview_screen.dart`'s notification-bell placeholder (line
  129 — re-verify); nest the equivalent route under `/overview`; update
  the call site.
- [X] T012 [P] [US2] Widget tests for the Tier B conversions, same
  pattern as T008. **Result**: same fix needed (real `GoRouter` in each
  harness, reusing the actual production route builders rather than
  reimplementing them, so the test can't silently drift from prod). 4
  pre-existing tests fixed (1 in `overview_screen_test.dart`, 3 in
  `account_screen_test.dart`); all pass; full suite unaffected elsewhere.

**Checkpoint**: Tier B shippable — every placeholder entry point has a
real URL; Tier C still on its existing, unchanged `Navigator.push`.

### Tier C — dynamic provider override (optional/stretch — only if budget clearly allows)

- [X] T013 [US2] Converted `overview_screen.dart`'s `_openFilteredHistory`
  call site to a real route: added `overviewFilteredHistoryRoute` to
  `expenses_routes.dart` (reads `state.pathParameters['accountName']`,
  rebuilds the same `ProviderScope` override wrapping
  `TransactionHistoryScreen`), nested as `GoRoute(path:
  'group/:accountName', ...)` under `/overview`'s existing `history`
  route in `app_router.dart`. The call site now does
  `context.push('/overview/history/group/${Uri.encodeComponent(accountName)}')`
  — `accountName` is a free-text group name (spaces, Vietnamese
  diacritics), so it's percent-encoded going in; go_router decodes path
  segments automatically on the way out, so `pathParameters['accountName']`
  already arrives as the original string, no double-decoding needed. The
  now-dead `_openFilteredHistory` method and its 3 now-unused imports
  (`ProviderScope`'s only remaining use, `transaction_history.dart`, and
  `transaction_history_screen.dart`) were removed (Constitution
  Principle I, matching T010's precedent).
- [X] T014 [P] [US2] Updated the shared `_harness()` in
  `overview_screen_test.dart` to nest the real `overviewFilteredHistoryRoute`
  builder under its `history` route (mirroring T008/T012's "reuse the
  actual production route builder" pattern). **Result**: the pre-existing
  `"Xem chi tiết →" opens transaction history filtered to that account's
  group` test needed **zero body changes** — its existing assertions
  (`find.byType(TransactionHistoryScreen)` + reading
  `selectedTransactionHistoryFilterProvider` from the pushed screen's
  container) already worked identically once the harness could resolve
  the route; verified by running it in isolation before touching anything
  else. Full suite re-run afterward: still exactly 428/428 (same count as
  T016 — no new test file added, one pre-existing harness extended).

**Checkpoint**: All 7 original call sites converted — reached.

---

## Phase 3: Polish

- [X] T015 Run `dart format --output=none --set-exit-if-changed lib test`
  and `flutter analyze` — both clean.
- [X] T016 Run the full `flutter test` suite — **428/428 passing**, same
  count as baseline (no new test files added in this feature — existing
  tests' harnesses were fixed in place, not supplemented — so the count
  staying exactly at 428 is the expected, correct outcome, not a gap).
  Re-confirmed after Tier C (T013/T014) landed — still 428/428.

---

## Notes

- P1 (T001-T002) is small and independent of P2 — do it first regardless
  of how much of P2 ends up fitting.
- Each Tier boundary in P2 is a safe stopping point (spec.md FR-008) —
  commit after each tier, not only at the very end, so partial progress
  is never lost to a budget cutoff mid-tier.
- Re-verify every cited line number against the current file before
  editing — this session has seen line numbers hold steady across
  features so far, but the code has changed since this plan's research.
