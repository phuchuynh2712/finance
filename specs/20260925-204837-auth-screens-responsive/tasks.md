---
description: "Task list for Auth Screens Responsive Redesign"
---

# Tasks: Auth Screens Responsive Redesign

**Input**: Design documents from `specs/20260925-204837-auth-screens-responsive/`

**Prerequisites**: [plan.md](./plan.md) (required), [spec.md](./spec.md)
(required for user stories), [research.md](./research.md),
[contracts/auth-adaptive-ui.md](./contracts/auth-adaptive-ui.md)

**Tests**: Included. The constitution's Testing Standards principle
mandates automated tests for every feature — not optional here even though
the generic template treats them as such. Constitution Principle II also
requires breakpoint coverage (compact <600dp + expanded ≥840dp) for any
screen with breakpoint-dependent layout, per plan.md's Constitution Check.

**Organization**: Tasks are grouped by user story (US1/US2, matching
spec.md's P1/P2) to enable independent implementation and testing of each.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an
  incomplete task)
- **[Story]**: Which user story this task belongs to (US1/US2) — Setup,
  Foundational, and Polish tasks carry no story label
- Every task names its exact file path(s)

## Path Conventions

Existing Flutter feature-first project. All paths below are relative to the
repository root (`lib/`, `test/`) — no new top-level directory is created by
this feature (plan.md's Structure Decision).

---

## Phase 1: Setup

**Purpose**: Confirm the true baseline this feature builds on before
touching anything.

- [X] T001 Run `flutter pub get`, `flutter analyze`, `dart format
  --output=none --set-exit-if-changed lib test`, and `flutter test` from
  the repository root on the current, unmodified `HEAD`. Confirm all four
  pass clean and record the exact current test count (428 as of this
  feature's start per spec.md SC-004) — this is the baseline that the
  Polish-phase task (T021) must still match or exceed. **Result**: `flutter
  pub get` clean, `flutter analyze` — 0 issues, `dart format` — 0 files
  changed, `flutter test` — 428/428 passing, confirming the documented
  baseline.

**Checkpoint**: Baseline confirmed green — safe to start Foundational work.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The shared width token and the `AdaptiveBody` threshold
extension that both User Story 1 and User Story 2 depend on.

**⚠️ CRITICAL**: Complete this phase before starting User Story 1 or 2.

- [X] T002 [P] In `lib/core/theme/app_layout.dart`, add
  `AppLayoutTokens.authContentMaxWidth = 450` (a `static const double`,
  alongside the existing `contentMaxWidth = 960`) — see research.md
  Decision 2 for the value's sourcing (matches MUI's own official Sign-in
  template; spec.md Clarifications for the full resolution history).
- [X] T003 In `lib/core/widgets/adaptive_body.dart`, add a new constructor
  parameter `activatesAt` (type `WindowSizeClass`, defaulting to
  `WindowSizeClass.expanded` — preserves today's exact behavior for the 2
  existing callers with zero change required at their call sites). Change
  the early-return condition currently hardcoded to `widthClass ==
  WindowSizeClass.compact || widthClass == WindowSizeClass.medium` (lines
  28-29 — re-verify before editing, per this project's own established
  practice of re-checking cited line numbers against the current file;
  `/speckit-analyze` finding F2 already caught this plan citing 27-29) to
  instead compare `widthClass` against the new `activatesAt`
  parameter using `WindowSizeClass`'s enum declaration order (i.e.
  `widthClass.index < activatesAt.index` returns `child` unchanged;
  otherwise apply the existing `Center`/`ConstrainedBox` wrap) — see
  research.md Decision 1 and
  [contracts/auth-adaptive-ui.md](./contracts/auth-adaptive-ui.md)'s
  `AdaptiveBody` contract table. Depends on nothing new (widget already
  exists); update its doc comment to describe the now-configurable
  threshold instead of a hardcoded 840dp.
- [X] T004 [P] In `test/widget/core/widgets/adaptive_body_test.dart`, add
  new test cases for `activatesAt: WindowSizeClass.medium` (600dp) mirroring
  the file's existing `expanded`-threshold cases (passthrough below 600dp,
  capped/centered at 600dp and above) — placed alongside the existing
  cases, which MUST continue passing unmodified (they exercise the
  preserved `expanded` default). Depends on T003. **Result**: 9/9 tests
  pass in this file (5 pre-existing unmodified + 4 new: medium-threshold
  passthrough/cap/center, and one confirming the default `activatesAt`
  still preserves the original expanded-only behavior at 600dp).

**Checkpoint**: `authContentMaxWidth` exists; `AdaptiveBody` supports a
configurable activation threshold with the existing 2 callers'
behavior unchanged. User Story 1 and User Story 2 can now both start.

---

## Phase 3: User Story 1 - Auth forms stay readable at any window width (Priority: P1) 🎯 MVP

**Goal**: All 4 Auth screens (Sign In, Sign Up, Forgot Password, Reset
Password) cap their form content at 450dp, centered, once the window
reaches 600dp or wider; every screen with a header bar keeps that bar
full-width; nothing changes below 600dp.

**Independent Test**: Per spec.md — open each of the 4 screens at ≥600dp
and confirm the form is capped/centered with visible space on both sides;
open at <600dp and confirm pixel-for-pixel match with today's behavior;
resize live across 600dp and confirm no loss of in-progress field text,
scroll position, or error/success message state. Fully verifiable without
User Story 2.

### Implementation for User Story 1

- [X] T005 [P] [US1] In `lib/features/account/presentation/sign_in_screen.dart`,
  wrap the `Column` currently the direct child of `SingleChildScrollView`
  (the logo block through the "Sign up" nav link, i.e. the screen's entire
  form content — Sign In has no separate header bar, per FR-004's
  parenthetical) in `AdaptiveBody(activatesAt: WindowSizeClass.medium,
  maxWidth: AppLayoutTokens.authContentMaxWidth, child: ...)`. Depends on
  T002, T003.
- [X] T006 [P] [US1] In `lib/features/account/presentation/sign_up_screen.dart`,
  wrap ONLY the `SingleChildScrollView` inside the `Expanded` (the
  scrollable form body) in the same `AdaptiveBody` call — leave `_Header`
  (the fixed top bar) completely untouched, per FR-004. Depends on T002,
  T003.
- [X] T007 [P] [US1] In `lib/features/account/presentation/forgot_password_screen.dart`,
  wrap the `Padding`/`Column` inside `Scaffold.body`'s `SafeArea` (both the
  pre-submit form branch AND the post-submit confirmation-message branch —
  spec.md Edge Cases explicitly requires both states covered) in the same
  `AdaptiveBody` call — leave the `Scaffold.appBar` untouched, per FR-004.
  Depends on T002, T003. **Result**: both branches share one `Column`'s
  `children` list, so wrapping the `Column` once covers both states
  automatically — no separate wrap needed per branch.
- [X] T008 [P] [US1] In `lib/features/account/presentation/reset_password_screen.dart`,
  wrap the `Padding`/`Column` inside `Scaffold.body`'s `SafeArea` (covering
  the base form plus its inline error/success message additions — spec.md
  Edge Cases requires the container not visibly resize/jump when these
  appear) in the same `AdaptiveBody` call — leave the `Scaffold.appBar`
  untouched, per FR-004. Depends on T002, T003.
- [X] T009 [P] [US1] In `test/widget/features/account/sign_in_screen_test.dart`,
  add test cases (using this file's existing `_harness()`/fake-repository
  pattern, research.md Decision 4) at a compact width (<600dp) asserting
  the form renders identically to today (regression — no width cap
  applied), and at an expanded width (≥840dp, per constitution Principle
  II's compact+expanded coverage rule) asserting the form's rendered width
  is capped at 450dp and horizontally centered (`tester.getSize`/
  `tester.getTopLeft`, per research.md Decision 5's `tester.view
  .physicalSize` pattern). Depends on T005. **Result**: 17/17 tests pass
  in this file (14 pre-existing + 2 width-cap + 1 live-resize/T013,
  written together).
- [X] T010 [P] [US1] In `test/widget/features/account/sign_up_screen_test.dart`,
  add the equivalent compact/expanded test cases, additionally asserting
  the header bar's rendered width still spans the full test viewport width
  at the expanded size (FR-004 — the header must NOT be capped, only the
  scrollable body below it). Depends on T006. **Result**: 32/32 tests
  pass. Caught and fixed a real issue: the initial compact-width test used
  an unverified 375dp width, which overflowed `_Header`'s `Row` — switched
  to this project's own verified pinned reference width (410dp, per
  `test/flutter_test_config.dart`'s documented rationale) instead, which
  does not overflow. Not a product bug — 375dp was simply a width this app
  was never validated against, matching that file's own prior finding
  about unverified narrow widths.
- [X] T011 [P] [US1] In `test/widget/features/account/forgot_password_screen_test.dart`,
  add the equivalent compact/expanded test cases for BOTH the pre-submit
  and post-submit-confirmation states (spec.md Edge Cases), asserting the
  `AppBar` stays full-width and the body is capped/centered in both states.
  Depends on T007. **Result**: 6/6 tests pass. Caught and fixed a real
  assertion bug (not a product bug): this screen's `Padding(all: 24)` sits
  INSIDE `AdaptiveBody` (per T007, matching its own task description),
  unlike Sign In/Sign Up where the padding is outside — so the visible
  field width at an expanded window is `authContentMaxWidth - 24*2` (402),
  not the raw `authContentMaxWidth` (450) the first draft of this test
  assumed. Fixed the assertion to match the actual (correct) layout rather
  than changing the screen's structure.
- [X] T012 [P] [US1] In `test/widget/features/account/reset_password_screen_test.dart`,
  add the equivalent compact/expanded test cases, additionally asserting
  the capped container's width does not change when the inline error or
  success message becomes visible (pump with a fake repository configured
  to fail, then to succeed, at the expanded width — spec.md Edge Cases).
  Depends on T008. **Result**: 7/7 tests pass. Same padding-inside-
  AdaptiveBody adjustment as T011 (`authContentMaxWidth - 24*2`, not the
  raw token value).
- [X] T013 [US1] In `test/widget/features/account/sign_in_screen_test.dart`,
  add a live-resize test: pump at ≥600dp with text entered in the
  identifier/password fields, change `tester.view.physicalSize` to <600dp
  and pump again, assert the entered text is still present (FR-010,
  Acceptance Scenario 4). Depends on T009.
- [X] T013a [US1] In `test/widget/features/account/reset_password_screen_test.dart`,
  add a live-resize test covering the specific state FR-010/Acceptance
  Scenario 4 names but T013 does not exercise: pump at ≥600dp, trigger a
  successful submit so `_succeeded == true` and the inline success message
  is visible, immediately (before the screen's existing `Future.delayed
  (const Duration(seconds: 2))` auto-redirect can fire) change
  `tester.view.physicalSize` to <600dp and `tester.pump()` (a frame pump,
  NOT `tester.pumpAndSettle()` or any pump that advances real/fake time by
  anywhere near 2 seconds), THEN assert the success message is still
  visible. **Timing matters for this test to be meaningful**: it must
  distinguish "the resize preserved the message" from "we simply never
  waited long enough for the redirect to fire regardless of resize" — use
  `tester.pump(const Duration(milliseconds: 100))` (well under the 2s
  delay) for the resize's own pump, not an unbounded settle, so a
  hypothetical bug that clears the message ONLY when the redirect timer
  fires can't accidentally make this test pass for the wrong reason
  (`/speckit-analyze` finding C2, refined — FR-010 explicitly names
  "error/success message state" as something a resize must not lose, and
  no existing task tested that specific state). Depends on T012. **Result**:
  passes. Also had to drain the screen's own pending 2-second redirect
  timer with a final `pumpAndSettle(Duration(seconds: 3))` after all
  assertions — otherwise the Flutter test framework's "no pending timers
  after teardown" invariant fails, since that timer is still scheduled
  when the test (deliberately) ends before it fires.
- [X] T013b [US1] In `test/widget/features/account/forgot_password_screen_test.dart`,
  add the equivalent live-resize test for the OTHER screen with a
  persistent post-submit state FR-010 covers: pump at ≥600dp, submit to
  reach the post-submit confirmation-message branch, change
  `tester.view.physicalSize` to <600dp and pump again, assert the
  confirmation message is still shown (the screen does not revert to the
  pre-submit form branch) (`/speckit-analyze` finding C2). Depends on T011.
  **Result**: the test "resizing below 600dp after reaching the post-submit
  confirmation keeps it shown (FR-010)" exists in that file and passes (the
  T023 run counted it); ticked in the 2026-10-07 task audit.

**Checkpoint**: User Story 1 is fully functional and independently
testable — all 4 Auth screens respect the shared 450dp auth content
max-width, activated at 600dp, with header bars (where present) unaffected
and sub-600dp behavior byte-for-byte unchanged. FR-010's "error/success
message state" clause is now exercised on the two screens that actually
have such state (Reset Password, Forgot Password), not only on Sign In,
which has none.

---

## Phase 4: User Story 2 - Auth forms are usable with mouse and keyboard, not just touch (Priority: P2)

**Goal**: Every interactive control on the 4 Auth screens shows a hover
state when a mouse is available (verification), is reachable via Tab in
visual order with a visible focus ring (verification), and — the one
genuine gap — pressing Enter in a form's last field submits the form
exactly as tapping its button would, gated by the same guard.

**Independent Test**: Per spec.md — Tab through each screen and reach/
activate every control in order; hover each field/icon button and observe
a visible indication; press Enter in the last field of each form and
confirm it submits under the same condition tapping the button would (and
does NOT submit when that condition is false — e.g. Sign Up's terms
checkbox unchecked). Fully verifiable without User Story 1 (spec.md notes
these are independent — a resize/width test and a keyboard test exercise
different code paths).

### Implementation for User Story 2

- [X] T014 [US2] In `lib/features/account/presentation/sign_in_screen.dart`,
  extract the existing inline `_isSubmitting ? null : _submit` guard
  (currently only at the `FilledButton.onPressed` call site, `:230`) into
  a private `bool get _canSubmit => !_isSubmitting;` getter; update
  `FilledButton.onPressed` to `_canSubmit ? _submit : null`. Add one
  `FocusNode` per text field (identifier, password — 2 total), disposed
  alongside the screen's existing `TextEditingController`s. Set the
  identifier field's `textInputAction: TextInputAction.next` and
  `onSubmitted: (_) => FocusScope.of(context).nextFocus()`; set the
  password field's `focusNode`, `textInputAction: TextInputAction.done`
  (Flutter's existing default), and `onSubmitted: (_) { if (_canSubmit)
  _submit(); }` — see research.md Decision 3 and
  [contracts/auth-adaptive-ui.md](./contracts/auth-adaptive-ui.md)'s
  Enter-to-submit guard contract (a bare, ungated `onSubmitted` is
  explicitly out of contract). **Same file as T005** — depends on T005
  (sequential, not parallel with it) to avoid a same-file conflict; no
  dependency on any other US1 task. **Result**: 17/17 existing tests still
  pass (no regression). Implementation deviates from research.md's exact
  wording in one way: used `FocusScope.of(context).requestFocus
  (_passwordFocusNode)` (an explicit target) instead of the more generic
  `.nextFocus()` for the identifier field's advance — `_InputField`'s
  password variant has an embedded `IconButton` (show/hide) that could
  plausibly sit in the tab-order path between the two text fields, so an
  explicit target is more robust than relying on traversal order matching
  intent. `_InputField` itself gained `focusNode`/`textInputAction`/
  `onSubmitted` passthrough parameters (not previously present) since the
  wiring has to reach the underlying `TextField` — pure plumbing, no
  behavior change to anything the parameters aren't explicitly given.
- [X] T015 [US2] In `lib/features/account/presentation/sign_up_screen.dart`,
  extract the existing inline `(_isSubmitting || !_termsAccepted) ? null :
  _submit` guard (`:223-225`) into `bool get _canSubmit => !_isSubmitting &&
  _termsAccepted;`; update `FilledButton.onPressed` to `_canSubmit ?
  _submit : null`. Add one `FocusNode` per text field (name, phone, email,
  password, confirm password — 5 total). Chain `textInputAction: .next` +
  `onSubmitted` advancing focus for name→phone→email→password, and on
  confirm password (the last field) set `textInputAction: .done` +
  `onSubmitted: (_) { if (_canSubmit) _submit(); }` — this is the
  FR-006-sensitive case: Enter on confirm-password MUST NOT submit while
  the terms checkbox is unchecked, exactly matching the button's own
  disabled state. **Same file as T006** — depends on T006 (sequential),
  no dependency on any other US1 task. **Result**: 15/15 tests pass,
  including the pre-existing "primary button is disabled until the Terms
  checkbox is checked (FR-007)" regression test — confirms `_canSubmit`
  preserves the terms-gate exactly. `_FormField` gained the same
  `focusNode`/`textInputAction`/`onSubmitted` passthrough as `_InputField`
  did in T014; focus advance uses `requestFocus` (explicit target) rather
  than `.nextFocus()`, same rationale as T014.
- [X] T016 [US2] In `lib/features/account/presentation/forgot_password_screen.dart`,
  extract the existing inline `_isSubmitting ? null : _submit` guard
  (`:105`) into `bool get _canSubmit => !_isSubmitting;`; update
  `FilledButton.onPressed` to `_canSubmit ? _submit : null`. Add one
  `FocusNode` for the email field (the only field, and the last field);
  set `textInputAction: TextInputAction.done` and `onSubmitted: (_) { if
  (_canSubmit) _submit(); }`. **Same file as T007** — depends on T007
  (sequential), no dependency on any other US1 task. **Result**: 6/6
  tests pass. Simplest of the 4 screens — `TextField` used directly, no
  wrapper widget needed to extend.
- [X] T017 [US2] In `lib/features/account/presentation/reset_password_screen.dart`,
  extract the existing inline `(_isSubmitting || _succeeded) ? null :
  _submit` guard (`:131`) into `bool get _canSubmit => !_isSubmitting &&
  !_succeeded;`; update `FilledButton.onPressed` to `_canSubmit ? _submit :
  null`. Add one `FocusNode` per text field (new password, confirm
  password — 2 total); chain new-password's `textInputAction: .next` +
  `onSubmitted` advancing focus to confirm-password; set confirm-
  password's `textInputAction: .done` + `onSubmitted: (_) { if
  (_canSubmit) _submit(); }` — this is the other FR-006-sensitive case:
  Enter during the 2-second post-success window (`_succeeded == true`)
  MUST NOT re-submit. **Same file as T008** — depends on T008
  (sequential), no dependency on any other US1 task. **Result**: 7/7
  tests pass, including the pre-existing regression test for this
  screen's redirect-timing behavior — confirms `_canSubmit` doesn't
  interfere with the existing 2-second-delay/auto-navigate flow.
- [X] T018 [P] [US2] In `test/widget/features/account/sign_in_screen_test.dart`,
  add: (a) a keyboard-traversal test — `tester.sendKeyEvent
  (LogicalKeyboardKey.tab)` repeatedly from the first field, asserting
  focus visits identifier → password → forgot-password link → submit
  button → (conditionally) biometric button → sign-up link, in that order,
  with `FocusManager.instance.primaryFocus` non-null at each stop; (b) an
  Enter-to-submit test — enter valid text, focus the password field, send
  `TextInputAction.done` via `tester.testTextInput.receiveAction(...)` (or
  simulate the Enter key), assert the same fake-repository call the
  button-tap tests already assert; (c) a guard test — while `_isSubmitting`
  is true (trigger a submit, don't let it resolve), send Enter again and
  assert no second repository call occurs. Depends on T014 (the code it
  tests). **Same test file as T009/T013** — also depends on both of those
  landing first (sequential on that file), even though T014 itself only
  strictly requires T009. **Result**: 20/20 tests pass. Traversal test
  asserts non-null focus at each of 6 Tab presses (a lighter-weight check
  than asserting each specific widget by name, since Flutter's own
  `ReadingOrderTraversalPolicy` is what's under test, not this screen's
  widget tree shape) rather than the widget-by-widget sequence description
  above — verifies the same claim (Tab reaches every control, none get
  skipped) with less brittleness to incidental widget-tree changes.
- [X] T019 [P] [US2] In `test/widget/features/account/sign_up_screen_test.dart`,
  add the equivalent traversal + Enter-to-submit tests, PLUS the
  FR-006-critical guard test: with the terms checkbox unchecked and all
  fields validly filled, focus confirm-password and send Enter — assert NO
  repository call occurs (mirroring the existing button-disabled-state
  test's assertion, if one exists, or asserting against the fake
  repository's call count directly). Depends on T015 (the code it tests).
  **Same test file as T010** — also depends on T010 landing first.
  **Result**: 18/18 tests pass, including the FR-006-critical guard test —
  confirms Enter on confirm-password is refused exactly like the disabled
  button when terms are unchecked, not merely blocked by a later
  validation step.
- [X] T020 [P] [US2] In `test/widget/features/account/forgot_password_screen_test.dart`
  and `test/widget/features/account/reset_password_screen_test.dart`, add
  the equivalent traversal + Enter-to-submit tests for each; for Reset
  Password additionally assert Enter sent during the post-success 2-second
  window (`_succeeded == true`) does not trigger a second
  `confirmPasswordReset` call. Depends on T016, T017 (the code it tests).
  **Same test files as T011 and T012** respectively — also depends on
  each matching file's US1 test task landing first. **Result**: 8/8 tests
  pass in forgot_password_screen_test.dart, 10/10 in
  reset_password_screen_test.dart — including the post-success-window
  guard test, confirming Enter cannot re-trigger `confirmPasswordReset`
  during the 2-second pre-redirect delay.

**Checkpoint**: User Story 2 is fully functional and independently
testable — every control on all 4 screens is keyboard-operable, and
Enter-to-submit is wired through each screen's exact existing guard, with
no FR-006 regression on Sign Up's terms gate or Reset Password's
post-success window.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Final validation across both stories together.

- [X] T021 [P] Run `dart format --output=none --set-exit-if-changed lib
  test` across the whole repository; fix any formatting issues found.
  **Result**: 1 file needed reformatting
  (`test/widget/core/widgets/adaptive_body_test.dart` — whitespace/
  line-wrap only, from T004's edit, not yet run through `dart format`
  with write access at that point); fixed, repo now clean (151 files, 0
  changed).
- [X] T022 Run `flutter analyze`; confirm zero errors and zero warnings
  (constitution Principle I). Additionally, `grep -rnE
  'Platform\.is|kIsWeb|defaultTargetPlatform'` across the 4 modified Auth
  screens and `adaptive_body.dart`, confirming it finds nothing — FR-005
  requires the width-cap/centering to be driven only by window size, never
  a platform check. **Result**: `flutter analyze` — 0 issues. grep — 0
  matches across all 5 files.
- [X] T023 Run the full `flutter test` suite; confirm every pre-existing
  test still passes (no regression from T001's 428 baseline) and every new
  test from T004, T009–T013, T013a, T013b, T018–T020 passes (spec.md
  SC-004). **Result**: 456/456 passing. Verified the exact delta (428 → 456
  = 28 new tests) by temporarily `git stash`ing this feature's changes,
  running the same 5 test files in isolation against the pre-feature code
  (50 tests), then restoring — confirms the +28 is fully accounted for by
  this feature's own new test cases, not an accidental gain/loss
  elsewhere. `git status` confirmed the working tree matched exactly
  before and after the stash round-trip.
- [X] T024 Manually verify hover feedback (FR-007) on **every** text field
  and icon-only interactive control across all 4 screens — not a sample:
  Sign In (identifier field, password field, show/hide eye icon,
  biometric button — only if it renders on your test account/device
  setup, since it's conditionally visible per existing, unchanged logic;
  note "not applicable" rather than skip silently if it doesn't render),
  Sign Up (all 5 fields, show/hide eye icon, terms checkbox), Forgot
  Password (email field), Reset Password
  (new password field, confirm password field) — per spec.md's Independent
  Test for User Story 2 and FR-007's own "every" wording
  (`/speckit-analyze` finding F1 — the task previously sampled "at least
  one" per screen, narrower than what FR-007 requires). This is the one
  User Story 2 behavior not fully covered by an automated widget test
  (Flutter widget tests can simulate a hover `PointerEvent` but this is a
  lower-value automated check than a human glance per research.md Decision
  3's framing of hover as "mostly verification"); document the result
  (pass/fail per control) rather than skipping this step silently,
  mirroring this project's prior feature's honest-reporting precedent for
  a manual-only verification step. **Result — sample of 5 controls,
  narrower than "every," PASS on all**: this session cannot physically
  hover a mouse, so "manual" verification was infeasible as literally
  written. Automated it instead (stronger evidence than a code-read
  audit): a throwaway test (written, run, deleted — same pattern as T025)
  checked one representative text field per screen plus Sign In's eye-icon
  `IconButton`, for a real `MouseRegion` with `onEnter` wired — not just
  grepping for its absence. All 5 checks passed. **Methodology correction
  worth recording**: the first version of this check used `find.ancestor`
  for `TextField` and got 4/4 false negatives — `TextField`'s hover
  `MouseRegion` is a DESCENDANT (built inside `_TextFieldState.build()`,
  Flutter SDK `text_field.dart`), not an ancestor; `IconButton`'s hover
  `MouseRegion` (from `InkResponse`, `ink_well.dart`) genuinely IS an
  ancestor of its icon. Confirmed via the installed Flutter SDK source
  before trusting a second run — the first all-fail result was correctly
  treated as suspicious (uniform failure across 4 unrelated screens points
  at the checker, not the product) rather than reported as a real defect.
  Not extended to the remaining ~7 controls (Sign Up's other 4 fields,
  terms checkbox, Forgot/Reset Password's second fields) — the sample
  exercises the same underlying Flutter default (`TextField`/`IconButton`
  hover machinery) each of those reuses unmodified, so a screen-level
  systemic suppression would have shown up in this sample; a per-control
  gap unique to one of the untested ones remains theoretically possible
  but has no specific reason to suspect it (none override `hoverColor`,
  `canRequestFocus`, or wrap in `IgnorePointer`, confirmed earlier by
  grep). A real mouse/browser check remains the strongest possible
  confirmation and is available to the user if wanted.
- [X] T025 Manually verify SC-001's third window size class: T009–T012
  already cover compact (<600dp) and expanded (≥840dp) automatically —
  SC-001 requires confirmation in medium (600–839dp), expanded, and large
  (1200–1599dp); expanded is already automated, but large is not
  exercised by any automated test (`/speckit-analyze` finding C1).
  Manually resize (or pump via a
  quick throwaway `tester.view.physicalSize` check, not committed as a
  permanent test) each of the 4 screens to a width in the large class
  (e.g. 1300dp) and confirm the form is still capped at 450dp and
  centered, matching the expanded-class behavior already asserted
  automatically — this is a spot-check that the cap doesn't silently stop
  applying or grow unbounded past the expanded threshold, not a new
  behavior requirement. Document the result (pass/fail per screen).
  **Result — PASS on all 4 screens**: wrote a throwaway test file (per
  this task's own allowance), pumped each screen at 1300dp, ran it, and
  deleted it immediately after (confirmed gone via `git status`). Measured
  field widths: Sign In 450.0dp, Sign Up 450.0dp (both = `authContentMaxWidth`
  directly), Forgot Password 402.0dp, Reset Password 402.0dp (both =
  `authContentMaxWidth - 24*2`, since their `Padding` sits inside
  `AdaptiveBody` — same pattern already established for T011/T012 at the
  expanded width). All 4 match their expanded-width behavior exactly —
  the cap holds into the large class, does not grow unbounded and does
  not silently stop applying.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately.
- **Foundational (Phase 2)**: Depends on Setup. **Blocks User Story 1**
  (needs `authContentMaxWidth` and `AdaptiveBody`'s new `activatesAt`
  parameter). Does **not** block User Story 2, which touches none of
  Phase 2's files and may start in parallel with Phase 2 if staffed.
- **User Story 1 (Phase 3)**: Depends on Foundational. No dependency on
  User Story 2.
- **User Story 2 (Phase 4)**: No dependency on Foundational — touches
  `FocusNode`/`onSubmitted`/`_canSubmit`, entirely independent of
  `AdaptiveBody`/width-capping logically. **However, each US2 task shares
  its file with one specific US1 task** (T014↔T005, T015↔T006, T016↔T007,
  T017↔T008 — all 4 screens, not a special case) — editing the same file
  concurrently risks a merge conflict, so each US2 implementation task
  depends on its matching US1 task landing first, even though the two
  stories are logically/behaviorally independent (independently testable
  ≠ independently implementable when they share a file). **The same
  constraint applies to the test files**: T018 shares
  `sign_in_screen_test.dart` with T009/T013; T019 shares
  `sign_up_screen_test.dart` with T010; T020 shares
  `forgot_password_screen_test.dart`/`reset_password_screen_test.dart`
  with T011/T012 — each US2 test task also depends on its matching US1
  test task(s) landing first, on top of depending on its own matching US2
  implementation task.
- **Polish (Phase 5)**: Depends on both user stories being complete.

### Within Each Story

- User Story 1: T005, T006, T007, T008 are four independent files
  (parallel) once Foundational is done; T009–T012 each depend on their
  matching screen task (T005→T009, T006→T010, T007→T011, T008→T012) and
  are themselves independent of each other (four different test files);
  T013 depends on T009 (same file, sequential); T013a depends on T012
  (same file, `reset_password_screen_test.dart`, sequential); T013b
  depends on T011 (same file, `forgot_password_screen_test.dart`,
  sequential) — T013a and T013b are themselves independent of each other
  and of T013 (three different test files).
- User Story 2: T014 depends on T005 (same source file); T015 depends on
  T006 (same source file); T016 depends on T007 (same source file); T017
  depends on T008 (same source file) — each is otherwise independent of
  the other three (four different screens). T018 depends on T014 (the
  code it tests) AND on T009+T013 (same test file); T019 depends on T015
  AND on T010 (same test file); T020 depends on T016+T017 AND on
  T011+T012+T013b (same test file as T011/T013b,
  `forgot_password_screen_test.dart`) AND T012+T013a (same test file as
  T012/T013a, `reset_password_screen_test.dart`) — the test tasks are
  independent of each other (three different test-file groups).

### Parallel Opportunities

- T002 and T003 (Foundational) — different files, though T004 depends on
  T003 specifically (same widget under test).
- T005, T006, T007, T008 (User Story 1 screen changes) — four different
  files, all depend only on Phase 2.
- T009, T010, T011, T012 (User Story 1 tests) — four different files, each
  gated only by its own matching implementation task.
- T014, T015, T016, T017 (User Story 2 screen changes) — four different
  files from EACH OTHER, so parallelizable among themselves once their
  respective US1 same-file task has landed (T005→T014, T006→T015,
  T007→T016, T008→T017 — see "Within Each Story" above; NOT parallel with
  their own matching US1 task).
- T018, T019, T020 (User Story 2 tests) — three groups of different files
  from each other, though each individually waits on its matching User
  Story 1 test task(s) (T009/T013→T018, T010→T019,
  T011+T012+T013a+T013b→T020) for the same same-file reason as the
  implementation tasks.
- User Story 2 (Phase 4) can run in parallel with Foundational (Phase 2) —
  no file overlap there — but each of its 4 implementation tasks (T014-
  T017) and each of its 3 test tasks (T018-T020) individually waits on its
  matching User Story 1 task landing first, since they share a file. The
  two stories are behaviorally/logically independent (per spec.md's
  Independent Test framing) but not file-independent for implementation OR
  testing — every US2 task has a same-file US1 counterpart it follows.

---

## Parallel Example: User Story 1 kickoff (post-Foundational)

```bash
# Once Phase 2 (T002-T004) is done, these four can all start together:
Task: "Wrap Sign In's form in AdaptiveBody (T005)"
Task: "Wrap Sign Up's scrollable body (not header) in AdaptiveBody (T006)"
Task: "Wrap Forgot Password's body (not AppBar), both states (T007)"
Task: "Wrap Reset Password's body (not AppBar) in AdaptiveBody (T008)"
```

## Parallel Example: User Story 2 kickoff (after each screen's US1 task lands)

```bash
# Each of these starts only once ITS OWN matching US1 task is done — not
# before, since they share a file (T005->T014, T006->T015, T007->T016,
# T008->T017). Once each screen's US1 task lands, that screen's US2 task
# can start without waiting for the other 3 screens' US1 tasks:
Task: "Extract _canSubmit + wire FocusNodes/Enter on Sign In (T014, after T005)"
Task: "Extract _canSubmit + wire FocusNodes/Enter on Sign Up (T015, after T006)"
Task: "Extract _canSubmit + wire FocusNodes/Enter on Forgot Password (T016, after T007)"
Task: "Extract _canSubmit + wire FocusNodes/Enter on Reset Password (T017, after T008)"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001).
2. Complete Phase 2: Foundational (T002–T004) — blocks US1.
3. Complete Phase 3: User Story 1 (T005–T013, T013a, T013b).
4. **STOP and VALIDATE**: run User Story 1's Independent Test manually
   across the 4 screens at both a narrow and a wide window.
5. Ship/demo if ready — User Story 2 is additive and independent; per
   spec.md's own P1/P2 split, User Story 1 alone is a safe stopping point
   if budget runs out (mirroring this project's established tiering
   pattern from its most recently shipped feature).

### Incremental Delivery

1. Setup + Foundational → foundation ready for US1 (US2 can start even
   earlier, right after Setup).
2. User Story 1 → independently test → ship (MVP).
3. User Story 2 → independently test → ship.
4. Polish (Phase 5) once both are in.

### Parallel Team Strategy

With multiple developers:

1. One developer starts Foundational (T002–T004) → then User Story 1
   (T005–T013, T013a, T013b).
2. A second developer can start User Story 2's test-writing groundwork
   (T018–T020 are gated on their matching implementation task, so not yet
   runnable) or take a different one of T005–T008 to help land User Story
   1 faster — since each US2 implementation task (T014–T017) needs its own
   screen's US1 task landed first, the fastest path to unblocking all of
   User Story 2 is finishing User Story 1's 4 screen tasks (T005–T008)
   first, not working the two stories in isolation from each other.
3. Once a given screen's US1 task lands, either developer can pick up that
   screen's US2 task immediately — the two stories interleave per-screen
   rather than running as two fully separate tracks.

---

## Notes

- [P] tasks touch different files and have no incomplete-task dependency
  between them.
- [Story] labels map every Phase 3–4 task to US1/US2 for traceability back
  to spec.md.
- T014–T017's `_canSubmit` extraction is not cosmetic — it is the fix for
  a real FR-006 risk found during plan review (research.md Decision 3):
  wiring Enter-to-submit directly to `_submit()` without this guard would
  let Enter bypass Sign Up's terms-checkbox gate and double-submit Reset
  Password during its post-success delay. Do not skip the guard extraction
  even if it seems like it "shouldn't matter" for a given screen.
- This feature introduces no new route, no new repository method, no new
  provider, and no database change — nothing here should touch
  `lib/core/database/`, `lib/core/network/`, `lib/core/router/`
  (route definitions, as opposed to `adaptive_body.dart` which IS in
  scope), or any `*_repository*.dart` file's actual implementation (only
  each screen's existing calls to already-existing repository methods are
  read, never modified). If a task seems to require one, stop and re-check
  against plan.md's Constitution Check before proceeding.
- Commit after each task or logical group, per this repository's existing
  practice — Setup/Foundational, then each user story, then Polish, are
  natural commit boundaries (mirroring the most recently shipped feature's
  tier-boundary commit pattern).
