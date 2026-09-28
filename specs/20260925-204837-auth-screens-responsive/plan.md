# Implementation Plan: Auth Screens Responsive Redesign

**Branch**: `20260925-204837-auth-screens-responsive` | **Date**: 2026-09-25 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from
`specs/20260925-204837-auth-screens-responsive/spec.md`

**Note**: No separate `data-model.md`/`quickstart.md` (matching the most
recent shipped feature's precedent for a similarly-scoped change) — this
feature introduces no new domain entity (spec.md Key Entities: N/A), so a
data model file would be empty overhead, and verification steps belong in
tasks.md rather than a separate quickstart. `contracts/` IS included,
unlike that precedent — this feature changes a shared `core/widgets/`
API (`AdaptiveBody`) that other screens already depend on, which
`adaptive-layout-foundation` (the feature that introduced `AdaptiveBody`)
already established warrants an internal UI contract.

## Summary

Width-cap and center the form content of all 4 Auth screens (Sign In, Sign
Up, Forgot Password, Reset Password) at 450dp once the window reaches the
medium window size class (600dp) or wider, leaving each screen's own header
bar (where one exists) full-width and every sub-600dp behavior untouched
(spec.md User Story 1). Separately, wire up keyboard/mouse affordances
these 4 screens never had: verified hover states (mostly already free from
Flutter's Material defaults), a verified Tab order matching visual order,
and — the one genuine gap — Enter-to-submit, which today only dismisses the
keyboard rather than submitting the form (spec.md User Story 2, research.md
Decision 3). Pure view-layer change; FR-006 forbids touching any business
logic, validation rule, or network call.

## Technical Context

**Language/Version**: Dart 3.11.0 / Flutter 3.41.0 (unchanged).

**Primary Dependencies**: No new package. Reuses `flutter_riverpod` and
`go_router` exactly as the 4 screens already do today — this feature adds
no provider and no route.

**Storage**: N/A — no data model, no persistence change (spec.md Key
Entities: N/A).

**Testing**: `flutter analyze`, `dart format --output=none
--set-exit-if-changed lib test`, `flutter test` (428 tests at this
feature's start). New/updated widget tests per screen, reusing each
screen's existing test harness (`test/widget/features/account/
{sign_in,sign_up,forgot_password,reset_password}_screen_test.dart` —
research.md Decision 4) rather than inventing a new one. Breakpoint
coverage (compact <600dp / expanded ≥840dp, per constitution Principle II)
follows the `tester.view.physicalSize =` pattern already established in
`test/widget/core/widgets/adaptive_body_test.dart` (research.md Decision 5)
— the only existing precedent for this in the codebase; `overview_screen_test.dart`
and `report_screen_test.dart` consume `AdaptiveBody` but do not actually
test at two widths, so they are not a usable precedent despite consuming
the same widget.

**Target Platform**: Android, iOS, Web — unchanged platform set. The
width-cap and keyboard work apply identically on every platform (window-
size-driven per constitution Principle III, never `Platform.is*`/`kIsWeb`);
User Story 2's keyboard/hover story is most visible on Web (the one
platform every user reaches Sign In on with a real keyboard by default)
but is not Web-exclusive code — a touch platform with a keyboard/mouse
attached gets the same behavior.

**Constraints**: No change to any business logic, validation rule, error
message, network call, or navigation destination (FR-006); no change to
sub-600dp behavior at all (FR-002); the 3 screens with a header bar (Sign
Up, Forgot Password, Reset Password) keep that bar full-width — only the
scrollable body is capped (FR-004).

**Scale/Scope**: 4 screens touched (`sign_in_screen.dart`,
`sign_up_screen.dart`, `forgot_password_screen.dart`,
`reset_password_screen.dart`); 1 new shared token
(`AppLayoutTokens.authContentMaxWidth`, research.md Decision 1); 1 modified
shared widget (`AdaptiveBody`, extended — not replaced — per research.md
Decision 1); up to 10 new `FocusNode`s across the 4 screens (research.md
Decision 3, one per text field: Sign In 2, Sign Up 5, Forgot Password 1,
Reset Password 2 — Sign Up's terms checkbox and every button stay
`FocusNode`-free, since only text fields need one for Enter-to-submit
wiring; Tab order for buttons/checkbox is already automatic per research.md
Decision 3); 1 new private `_canSubmit` getter per screen (4 total),
extracted from each screen's existing inline button-disable predicate so
the submit button and Enter-to-submit share one gating source of truth
(research.md Decision 3 — blocking correction: an ungated `onSubmitted`
would violate FR-006 on Sign Up specifically, by letting Enter bypass the
terms-checkbox gate).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

- **Principle I — Code Quality: PASS.** No new mixed-responsibility widget;
  the `AdaptiveBody` extension is a single new constructor parameter with a
  backward-compatible default, not a rewrite. `FocusNode` lifecycle
  (create/dispose) follows the exact pattern each screen already uses for
  its `TextEditingController`s.
- **Principle II — Testing Standards: PASS.** Every one of the 4 screens
  gets new widget-test coverage at both compact (<600dp) and expanded
  (≥840dp) width, per this principle's own explicit breakpoint-coverage
  rule — reusing the sole existing precedent for this pattern
  (`adaptive_body_test.dart`, research.md Decision 5) rather than
  inventing a new testing approach. Enter-to-submit and Tab-order get
  dedicated new test cases per screen (research.md Decision 3).
- **Principle III — User Experience Consistency & Adaptive Design: PASS —
  this feature directly implements it.** FR-001/FR-003/FR-005 are a literal
  application of this principle's own text ("Content MUST NOT stretch
  unbounded... MUST cap content width at a shared max-width token and
  center it... driven by the available window size, never by device or
  platform type"). FR-007/FR-008/FR-009 close this same principle's
  hover/focus-order/keyboard-activation clause, which the 4 screens
  predate.
- **Principle IV — Performance: PASS.** No new async work, no new list, no
  new query, no new provider — a `ConstrainedBox`/`FocusNode` addition to 4
  already-lightweight screens.
- **Recommended Architecture: PASS.** `AdaptiveBody` stays in `core/
  widgets/` (already had ≥2 consumers before this feature; gaining 4 more
  is consistent with why it lives in `core/` rather than a feature
  directory). No feature-local reimplementation of width-capping.
- **Multi-Platform Support: PASS.** No platform-specific code added; the
  width-cap and keyboard wiring are identical on Android/iOS/Web, matching
  this section's "layout decisions... window-size-driven" framing.
- **Security: PASS — N/A change.** FR-006 explicitly forbids touching any
  auth/validation/network logic; this feature is view-layer only.
- **Development Workflow: PASS (procedural).** The `AdaptiveBody` extension
  is a breaking-change-adjacent (though backward-compatible) change to a
  shared `core/` widget — gets called out in the PR description per the
  constitution's Development Workflow breaking-change bullet, even though
  its default behavior for existing callers (Tổng quan, Báo cáo) is
  unchanged.

**Post-design re-check**: PASS. No new package, no new external service, no
constitution violation introduced by the Phase 1 design below.

## Project Structure

### Documentation (this feature)

```text
specs/20260925-204837-auth-screens-responsive/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── contracts/           # Phase 1 output — auth-adaptive-ui.md
├── checklists/          # Spec quality checklist
└── tasks.md             # Phase 2 output (/speckit-tasks)
```

### Source Code (repository root)

```text
lib/core/theme/app_layout.dart         # MODIFIED: + AppLayoutTokens.
                                        # authContentMaxWidth (450dp,
                                        # research.md Decision 2)

lib/core/widgets/adaptive_body.dart    # MODIFIED: new constructor param
                                        # to activate the cap starting at
                                        # WindowSizeClass.medium (600dp)
                                        # instead of only .expanded (840dp)
                                        # — default preserves today's
                                        # .expanded-only behavior for
                                        # existing callers (research.md
                                        # Decision 1)

lib/features/account/presentation/
├── sign_in_screen.dart                # MODIFIED: wrap form in
│                                       # AdaptiveBody; 2 FocusNodes +
│                                       # _canSubmit getter (negation of
│                                       # the existing _isSubmitting
│                                       # button guard) + Enter-to-submit
│                                       # wiring through it
├── sign_up_screen.dart                # MODIFIED: wrap scrollable body
│                                       # (not header) in AdaptiveBody;
│                                       # 5 FocusNodes + _canSubmit getter
│                                       # (negation of the existing
│                                       # _isSubmitting || !_termsAccepted
│                                       # button guard — the FR-006-
│                                       # sensitive one) + Enter-to-submit
├── forgot_password_screen.dart        # MODIFIED: wrap body (not AppBar)
│                                       # in AdaptiveBody, both submitted/
│                                       # unsubmitted branches; 1 FocusNode
│                                       # + _canSubmit getter (negation of
│                                       # the existing _isSubmitting button
│                                       # guard) + Enter-to-submit
└── reset_password_screen.dart         # MODIFIED: wrap body (not AppBar)
                                        # in AdaptiveBody; 2 FocusNodes +
                                        # _canSubmit getter (negation of
                                        # the existing _isSubmitting ||
                                        # _succeeded button guard) +
                                        # Enter-to-submit, focus chained to
                                        # confirm-password field

test/widget/core/widgets/
└── adaptive_body_test.dart            # MODIFIED: new test cases for the
                                        # medium-activation parameter,
                                        # alongside existing expanded-
                                        # activation cases (unchanged)

test/widget/features/account/         # MODIFIED: width-cap + Tab-order +
                                        # Enter-to-submit test cases added
                                        # to all 4 existing screen test
                                        # files, reusing each file's
                                        # existing harness (research.md
                                        # Decision 4)
```

**Structure Decision**: No new feature directory, no new file except test
files gaining new cases in place. `AdaptiveBody` and `AppLayoutTokens` stay
in `core/` and are extended, not duplicated — matching the constitution's
"something belongs in `core/` only if used by ≥2 features" rule, which
already held before this feature (Tổng quan, Báo cáo) and holds more
strongly after (4 more consumers). All work stays on this feature's own
branch, `20260925-204837-auth-screens-responsive`.

## Phase 0: Research Summary

See [research.md](./research.md) — 5 decisions: extend `AdaptiveBody` with
a configurable activation threshold rather than building a second widget or
inlining the cap per screen, since the existing widget's built-in threshold
(840dp) does not match this feature's required threshold (600dp) — a real
mismatch found by reading the widget's own code and test, not assumed
(Decision 1); a new, dedicated `authContentMaxWidth` token at 450dp,
distinct from the dashboard's 960dp `contentMaxWidth` (Decision 2,
finalized during `/speckit-clarify` after two corrections — see spec.md
Clarifications); the concrete `FocusNode`/`textInputAction`/`onSubmitted`
wiring pattern for Enter-to-submit and intermediate-field focus advance,
scoped to view-layer-only per FR-006, gated through a shared `_canSubmit`
getter so Enter can never bypass a screen's existing submit-button guard
(Decision 3 — this guard was a correction found during plan review, not
in the decision's first draft: an ungated `onSubmitted` would have let
Enter submit Sign Up with its terms checkbox unchecked, a real FR-006
violation); reuse of each of the 4
screens' own existing widget-test harness, no new test infrastructure
(Decision 4); reuse of `adaptive_body_test.dart`'s `tester.view.physicalSize`
pattern for compact/expanded breakpoint coverage, the sole existing
precedent for this in the codebase (Decision 5).

## Complexity Tracking

No constitution violations. Extending `AdaptiveBody` rather than leaving it
untouched and duplicating its logic in a second widget is the
lower-complexity choice, not added complexity — it keeps width-capping/
centering defined in exactly one place in `core/widgets/`, consistent with
why the constitution requires promotion to `core/` in the first place.
