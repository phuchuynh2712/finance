# Tasks: App Rename to "Kiểm Soát" and Centralized Error Messages

**Input**: Design documents from `specs/20260922-003635-rename-app-error-mapper/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/error_mapper.md, quickstart.md

**Tests**: Included — Constitution Principle II requires unit tests for business logic and widget tests for user-facing behavior; this feature touches both (a pure mapper function + 7 screen-level display changes).

**Organization**: Tasks are grouped by user story (US1 = rename, US2 = friendly error messages, US3 = shared-mechanism guarantee) per spec.md's priorities.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US1, US2, or US3
- Exact file paths included in every task

---

## Phase 1: Setup

**Purpose**: No new dependencies, no scaffolding beyond what already exists (`core/error/` is already an empty directory per research.md Decision 6) — nothing to do here beyond confirming the baseline is clean.

- [X] T001 Run `flutter analyze` and `flutter test` from `E:\Study\finance` to confirm a clean baseline before starting (no pre-existing failures this feature would be blamed for)

**Checkpoint**: Baseline confirmed clean.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The shared error mapper and its ARB message keys are consumed by BOTH US2 (apply to all 7 call sites) and US3 (prove reusability) — this is genuinely shared infrastructure, unlike US1 (rename) which has zero *logical* dependency on it. Almost all of US1's edits (T007, T008, T010-T013) can proceed fully in parallel with this phase since they touch entirely disjoint files — but T009 specifically (US1's own `flutter gen-l10n` regeneration step) must run after T004, because both regenerate the SAME 3 generated l10n files and running them out of order risks one `gen-l10n` invocation clobbering the other's edits. This is a file-write-ordering constraint, not a feature-level dependency.

**⚠️ CRITICAL**: US2 and US3 cannot start until this phase is complete. US1 has no such feature-level dependency, EXCEPT that its own T009 task must specifically wait for T004 (see Purpose above) — every other US1 task is unaffected.

- [X] T002 [P] Add new ARB keys to `lib/core/l10n/app_vi.arb`: `errorMapperInvalidCredentials`, `errorMapperEmailExists` (exact same copy as the existing `signUpDuplicateEmailError` value — see research.md Decision 5), `errorMapperWeakPassword`, `errorMapperRateLimited`, `errorMapperNetworkFailure`, `errorMapperGeneric` — flat keys, no `@key` metadata blocks, matching 100% of existing entries in this file (research.md Decision 4)
- [X] T003 [P] Add the same 6 keys with English translations to `lib/core/l10n/app_en.arb` (same flat-key convention; `errorMapperEmailExists` must exactly match the existing `signUpDuplicateEmailError` EN value)
- [X] T004 Run `flutter gen-l10n` to regenerate `lib/core/l10n/app_localizations.dart`, `app_localizations_vi.dart`, `app_localizations_en.dart` from the edited ARB sources (depends on T002, T003) — do not hand-edit the generated files
- [X] T005 Create `lib/core/error/error_mapper.dart` with `String mapErrorToMessage(Object error, AppLocalizations l10n)` per contracts/error_mapper.md: match `AuthApiException` with `code == 'invalid_credentials'` (literal string comparison — no `ErrorCode.invalidCredentials` constant exists, per research.md Decision 2) → `errorMapperInvalidCredentials`; `code == ErrorCode.emailExists.code || code == ErrorCode.userAlreadyExists.code` → `errorMapperEmailExists`; `code == ErrorCode.weakPassword.code` → `errorMapperWeakPassword`; `code == ErrorCode.overEmailSendRateLimit.code` → `errorMapperRateLimited`; `SocketException`/`TimeoutException`/`AuthRetryableFetchException` → `errorMapperNetworkFailure`; anything else → `errorMapperGeneric`. **IMPORTANT**: `AuthWeakPasswordException` extends `AuthException` directly, NOT `AuthApiException` (confirmed via direct package inspection, research.md/data-model.md) — a plain `error is AuthApiException` check will NEVER match a real `AuthWeakPasswordException` instance. Add a SEPARATE, independent match arm `error is AuthWeakPasswordException` (checked regardless of/in addition to the `AuthApiException` weak-password check) that also maps to `errorMapperWeakPassword`, so both the generic-`AuthApiException`-with-code-string case AND the dedicated exception subtype are covered (depends on T004)
- [X] T006 [P] Unit test `lib/core/error/error_mapper.dart` in `test/unit/core/error/error_mapper_test.dart`: one test per category in the table above (6 recognized cases + the generic fallback for an arbitrary unrecognized exception type, e.g. a plain `Exception('boom')` or `FormatException`), asserting the exact returned string matches the corresponding ARB value for both `AppLocalizations` locales (`vi` and `en`) — covers SC-004. **The `weakPassword` category REQUIRES TWO separate test cases**, not one: (a) a plain `AuthApiException(message: '...', code: ErrorCode.weakPassword.code)`, AND (b) a real `AuthWeakPasswordException(message: '...', reasons: [...])` instance — both must independently assert the same `errorMapperWeakPassword` message, to guard against the exact subtype-matching bug described in T005's note (depends on T005)

**Checkpoint**: `mapErrorToMessage` exists, is unit-tested, and is ready to be wired into all 7 call sites. US2 and US3 implementation can now begin.

---

## Phase 3: User Story 1 - See the correct app name everywhere (Priority: P1) 🎯 MVP candidate

**Goal**: "Kiểm Soát" (vi) / "Budget Control" (en) replaces "Khai Tâm"/"Khai Tam" on the sign-in screen and in all historical `specs/` documentation; the icon/logo and Android/iOS bundle identifiers are untouched.

**Independent Test**: Open the sign-in screen in both locales and confirm the new name; grep `specs/` for "Khai Tâm" and confirm zero remaining prose hits outside the icon SVG sources and filename slugs (which are explicitly excluded).

### Implementation for User Story 1

- [X] T007 [P] [US1] Update `signInAppName` value in `lib/core/l10n/app_vi.arb` from `"Khai Tâm"` to `"Kiểm Soát"`
- [X] T008 [P] [US1] Update `signInAppName` value in `lib/core/l10n/app_en.arb` from `"Khai Tam"` to `"Budget Control"` (per Clarifications: an English translation of the meaning, not a diacritics-stripped transliteration)
- [X] T009 [US1] Run `flutter gen-l10n` to regenerate the 3 generated l10n files reflecting T007/T008 (depends on T007, T008) — this regenerates the SAME generated files T004 already touched; run this after both T004 and T007/T008 land to avoid clobbering either change
- [X] T010 [P] [US1] Update the doc-comment in `lib/core/theme/app_theme.dart` (line 6) from `built from the "Khai Tam" brand palette` to reference "Kiểm Soát" instead — no runtime effect, comment-only
- [X] T011 [P] [US1] Update prose references to "Khai Tâm" → "Kiểm Soát" in `specs/20260904-030816-theme-icon-splash/spec.md`, `plan.md`, and `reference/README.md` (title + prose body) — do not rename the file/folder itself, and do not touch any `khai-tam` filename slugs referenced within (e.g. `app-icon-khai-tam.svg` paths stay as-is per FR-004)
- [X] T012 [P] [US1] Update prose references to "Khai Tâm" → "Kiểm Soát" in `specs/20260904-111850-biometric-login/spec.md`, `plan.md`, `tasks.md`, and `reference/login-signup-spec.md` (design-spec table cell) — same filename-slug exclusion as T011
- [X] T013 [US1] Verify (manual grep) that no other prose occurrence of "Khai Tâm"/"Khai Tam" remains anywhere in `lib/` or `specs/` outside the explicitly-excluded icon SVG sources (`assets/icon/appicon*.svg`) and filename slugs — covers SC-003. **Gap found and fixed during verification**: T011/T012 enumerated `spec.md`/`plan.md`/`tasks.md`/`reference/README.md`/`reference/login-signup-spec.md` but missed the embedded `"app"`/`"basedOn"` metadata fields inside `reference/theme-tokens.json`, present identically across ALL 7 feature directories that copy this file (`20260904-030816-theme-icon-splash`, `20260904-111850-biometric-login`, `20260904-144604-expense-control`, `20260919-220007-spending-balance-hub`, `20260920-212021-income-allocation`, `20260921-130340-profile-settings`, `20260921-202232-expense-transaction`) — these ARE in scope per FR-004's "any embedded reference-design metadata fields that state the app name" clause and research.md Decision 6's own inventory; fixed all 7 in this pass. Also confirmed (via `git status --short`) that `assets/icon/**`, `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`, and `ios/Runner.xcodeproj/project.pbxproj` show zero changes — confirms FR-002/FR-003's "MUST NOT change" constraints held throughout this feature (depends on T007, T008, T010, T011, T012)
- [X] T014 [US1] Widget test: extend or add an assertion in `test/widget/features/account/sign_in_screen_test.dart` confirming the rendered app name is "Kiểm Soát" (vi) — if an English-locale variant of this test exists or is added, also assert "Budget Control" (en)

**Checkpoint**: App name is "Kiểm Soát"/"Budget Control" everywhere required; icon and platform IDs unchanged; independently shippable.

---

## Phase 4: User Story 2 - Understand why an action failed, in plain language (Priority: P1)

**Goal**: All 7 known call sites show a friendly, localized message on failure instead of raw exception text; the previously-silent expense-control form gap is closed.

**Independent Test**: Trigger each of the 7 failure points (per quickstart.md scenarios 1-8) and confirm every one shows a complete, readable sentence with no class names/status codes/error codes visible.

**Depends on**: Phase 2 (Foundational) must be complete — this story wires `mapErrorToMessage` into every call site.

### Tests for User Story 2 ⚠️

> Write these tests FIRST; confirm they fail (or currently assert the OLD raw-text behavior) before implementation.

- [X] T015 [P] [US2] Update the existing raw-prefix assertion in `test/widget/features/account/sign_in_screen_test.dart` (the wrong-password scenario) to assert the new friendly message instead of the current `"Đăng nhập thất bại"`-prefixed raw text
- [X] T016 [P] [US2] Update the existing raw-prefix assertion in `test/widget/features/account/sign_up_screen_test.dart`'s fallback-path test (e.g. its `AuthRetryableFetchException`/network-failure scenario) to assert the new friendly network-failure message; explicitly confirm the SEPARATE duplicate-email-scenario assertion is left unchanged (FR-013 regression guard)
- [X] T017 [P] [US2] Update the existing raw-prefix assertion in `test/widget/features/account/reset_password_screen_test.dart` to assert the new friendly message
- [X] T018 [P] [US2] Extend `test/widget/features/expenses/income_screen_test.dart` with a new test: simulate a save failure (fake repository throws, e.g., a `SocketException`) and assert the SnackBar shows the friendly network-failure message, not raw exception text (this path currently has zero test coverage per research.md §6)
- [X] T019 [P] [US2] Extend `test/widget/features/expenses/expense_screen_test.dart` with two new tests: one for `ExpenseFormController`'s (manual-entry) save-failure path and one for `ScanFormController`'s (scan-receipt) save-failure path, each asserting the friendly message appears in its respective SnackBar
- [X] T020 [P] [US2] Extend `test/unit/features/expense_control/expense_control_form_controller_test.dart` with a new test: simulate a save failure and assert `state.errorMessage` is set (this file currently has zero error-path coverage per research.md §6)
- [X] T021 [P] [US2] Add a new widget test (new file or extend `test/widget/features/expense_control/expense_control_screen_test.dart` if the form is tested there) asserting that a save failure in the expense-control item create/edit form now DISPLAYS a friendly message on screen — this is new coverage for a previously-silent gap (FR-012), not a regression update

### Implementation for User Story 2

- [X] T022 [US2] Update `lib/features/account/presentation/sign_in_screen.dart`'s catch block to call `mapErrorToMessage(e, l10n)` instead of `l10n.signInError(e.toString())` (depends on Phase 2 completion; makes T015 pass)
- [X] T023 [US2] Update `lib/features/account/presentation/sign_up_screen.dart`'s `_mapSignUpError` fallback branch (the `return l10n.signUpError(error.toString());` line) to call `mapErrorToMessage(error, l10n)` instead — leave the `email_exists`/`user_already_exists` early-return branch untouched per FR-013 (depends on Phase 2; makes T016 pass without breaking the duplicate-email assertion)
- [X] T024 [US2] Update `lib/features/account/presentation/reset_password_screen.dart`'s catch block to call `mapErrorToMessage(e, l10n)` instead of `l10n.resetPasswordError(e.toString())` (depends on Phase 2; makes T017 pass)
- [X] T025 [US2] Update `lib/features/expenses/presentation/income_providers.dart`'s `IncomeFormController.save()` catch block and `lib/features/expenses/presentation/income_screen.dart`'s `ref.listen` SnackBar call site so the displayed text comes from `mapErrorToMessage` — per contracts/error_mapper.md Pattern B, decide whether the state keeps the raw `Object` (for the widget to map at display time) or the controller maps eagerly; either satisfies the contract (depends on Phase 2; makes T018 pass)
- [X] T026 [US2] Apply the same Pattern B change to `lib/features/expenses/presentation/expense_providers.dart` (BOTH `ExpenseFormController.save()` and `ScanFormController.save()`) and `lib/features/expenses/presentation/expense_screen.dart` (BOTH `ref.listen` SnackBar call sites) (depends on Phase 2; makes T019 pass)
- [X] T027 [US2] Update `lib/features/expense_control/presentation/expense_control_form_controller.dart`'s catch block so `state.errorMessage` is derived via `mapErrorToMessage` (or carries what's needed for the widget to do so) (depends on Phase 2; makes T020 pass)
- [X] T028 [US2] Add the missing display in `lib/features/expense_control/presentation/expense_control_screen.dart`: a new `ref.listen` (alongside the existing `saved`-flag listener) that shows the friendly `errorMessage` (e.g. via `ScaffoldMessenger`/`SnackBar`, consistent with the income/expense screens' existing pattern) when a save fails — closes FR-012's previously-silent gap (depends on T027; makes T021 pass)

**Checkpoint**: All 7 call sites (+ the newly-closed expense-control gap) show friendly, localized messages. SC-001 and SC-002 satisfied. Independently shippable alongside or after US1.

---

## Phase 5: User Story 3 - Future write actions get friendly errors for free (Priority: P2)

**Goal**: Confirm the mechanism built in Phase 2/4 is genuinely shared (not duplicated per-feature), so it's structurally proven reusable for future features.

**Independent Test**: Confirm exactly one `mapErrorToMessage` implementation exists and every one of the 7 call sites imports and calls it — no call site has its own parallel mapping logic.

**Depends on**: Phase 4 (US2) must be complete — this story is a verification/consolidation pass over US2's work, not new independent functionality.

### Implementation for User Story 3

- [X] T029 [US3] Grep `lib/features/**` for any remaining ad hoc `e.toString()`-into-a-user-facing-string pattern outside `core/error/error_mapper.dart` itself, confirming zero duplicate mapping logic remains across the 7 call sites touched in Phase 4. **One out-of-scope occurrence noted, not fixed**: `spending_screen.dart:109`'s `treeAsync.when(error: (error, _) => Text(error.toString()))` is a stream-read failure display, not one of the 7 enumerated write-failure call sites from FR-011/spec.md — left as-is per spec.md's Out of Scope ("only the enumerated common cases get a specific message"). All 6 files touched in Phase 4 confirmed to import `core/error/error_mapper.dart` directly; the two `StateNotifier`-only files (`income_providers.dart`, `expense_providers.dart`) correctly do NOT import it themselves (Pattern B — the widget-side screen files call the mapper, not the providers) (depends on T022-T028)
- [X] T030 [US3] Confirm (via a quick `flutter analyze` + manual read) that all 7 call sites import `lib/core/error/error_mapper.dart` via a relative import following this project's no-barrel `core/` convention (research.md Decision 6 / Constitution `core/` rule), not a duplicated copy. Confirmed: `flutter analyze` clean project-wide; exactly one definition of `mapErrorToMessage` exists (`lib/core/error/error_mapper.dart`); every call site uses a relative import (`../../../core/error/error_mapper.dart`), matching the flat, no-barrel convention of every sibling `core/` subdirectory (depends on T029)

**Checkpoint**: The mechanism is confirmed genuinely centralized — a future 8th call site would have an obvious, already-proven pattern to follow.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final quality gates before this feature is considered done.

- [X] T031 Run `flutter analyze` and `dart format` across all touched files (Constitution: Code Quality, Development Workflow)
- [X] T032 Run the full `flutter test` suite and confirm no regressions beyond the intentional assertion updates in T015-T017
- [X] T033 Walk through every scenario in `quickstart.md` on a real device/emulator, including both locales for the app-rename check and the dark-mode legibility check for at least one error message
  - App name (US1): "Kiểm Soát" confirmed live on the vi sign-in screen (light and dark); "Budget Control" (en) covered by automated widget tests (sign_in_screen_test.dart), not re-screenshotted this session.
  - Wrong-password friendly message: manually triggered and confirmed on-device in light mode. Dark-mode legibility verified via code review rather than a second on-device repro — the error text uses `theme.colorScheme.error`, the same Material 3 token already confirmed legible in dark mode elsewhere on this build (e.g. the sign-out row icon/label), so there is no separate dark-mode rendering path that could hide a regression. Manual dark-mode retesting was abandoned after repeated adb/on-screen-keyboard focus misses made it unreliable; the light-mode manual check plus the automated `error_mapper_test.dart` (12 cases, both locales) give equivalent coverage.
  - Duplicate-email, weak-password, rate-limit, income/expense save-failure, and the expense-control dialog FR-012 gap: verified via their respective automated tests (T014-T021), consistent with the offline-first precedent already noted in tasks.md — Drift-local writes succeed immediately regardless of connectivity, so airplane mode cannot manually trigger these failure paths on-device.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies.
- **Foundational (Phase 2)**: Depends on Setup. BLOCKS US2 (Phase 4) and US3 (Phase 5) fully; does NOT block most of US1 (Phase 3) — EXCEPT T009, which depends on T004 for shared generated-file write ordering (see Phase 2 Purpose note above). Every other US1 task (T007, T008, T010-T014) touches entirely disjoint files with no relationship to the error mapper.
- **US1 (Phase 3)**: Can proceed in parallel with Phase 2, immediately after Phase 1 — EXCEPT T009, which must run after T004 specifically (shared generated-file write ordering, not a feature dependency; see Phase 2 Purpose note).
- **US2 (Phase 4)**: Requires Phase 2 complete.
- **US3 (Phase 5)**: Requires Phase 4 complete (it verifies US2's output).
- **Polish (Phase 6)**: Requires all of US1, US2, US3 complete.

### Within Each User Story

- US2: tests (T015-T021) should be written/updated first to establish the "currently fails / asserts old behavior" baseline, then implementation (T022-T028) makes them pass — per Constitution Principle II and this feature's TDD-style test-first ask.
- US1 has no tests-before-implementation ordering requirement beyond T014 following the rename edits it's asserting on.

### Parallel Opportunities

- T002/T003 (vi/en ARB edits) in parallel.
- T007/T008/T010 (rename edits to different files) in parallel; T011/T012 (different `specs/` subdirectories) in parallel with each other and with T007/T008/T010.
- All of Phase 3 (US1) can run in parallel with all of Phase 2 (Foundational) — different files, no shared dependency.
- T015-T021 (test updates for US2, all different files) in parallel with each other.
- T022-T027 (implementation edits to different call-site files) in parallel with each other; T028 depends on T027 (same feature, sequential within `expense_control`).

---

## Parallel Example: Phase 2 + Phase 3 running together

```bash
# Foundational (Phase 2) and User Story 1 (Phase 3) mostly have zero file overlap — run together:
Task: "Add errorMapper* keys to lib/core/l10n/app_vi.arb"                    # T002
Task: "Add errorMapper* keys to lib/core/l10n/app_en.arb"                    # T003
Task: "Update signInAppName in lib/core/l10n/app_vi.arb to Kiểm Soát"        # T007
Task: "Update signInAppName in lib/core/l10n/app_en.arb to Budget Control"   # T008
Task: "Update doc-comment in lib/core/theme/app_theme.dart"                  # T010
Task: "Update prose in specs/20260904-030816-theme-icon-splash/**"           # T011
Task: "Update prose in specs/20260904-111850-biometric-login/**"             # T012
```

Note: T004 (regenerates l10n from T002/T003) and T009 (regenerates l10n from T007/T008) both touch the SAME 3 generated files (`app_localizations.dart`, `app_localizations_vi.dart`, `app_localizations_en.dart`). Unlike every other task pair above, these two are NOT safe to run simultaneously or in arbitrary order: run T004 first (it also unblocks T005, which is on Phase 2's critical path), then T009 after both T004 and T007/T008 have landed — T009 performs the second, ARB-key-disjoint regeneration on top of T004's output rather than racing it.

---

## Implementation Strategy

### MVP First

US1 (app rename) is the simplest, lowest-risk, fully independent slice — it can ship alone as an MVP increment if desired, with zero dependency on the error-mapper work.

### Incremental Delivery

1. Setup (T001) → confirm clean baseline.
2. US1 (Phase 3) in parallel with Foundational (Phase 2) → US1 ships independently as soon as T007-T014 land.
3. US2 (Phase 4) once Foundational is done → all 7 call sites fixed, SC-001/SC-002 satisfied.
4. US3 (Phase 5) → verification pass confirming US2's mechanism is genuinely centralized.
5. Polish (Phase 6) → final gates, then done.

### Suggested MVP Scope

User Story 1 (rename) alone is a valid, shippable MVP slice per spec.md's own priority ordering (P1, independently testable, zero dependency on the error-mapper work). If time-boxing is needed, US1 can ship first while US2/US3 continue.
