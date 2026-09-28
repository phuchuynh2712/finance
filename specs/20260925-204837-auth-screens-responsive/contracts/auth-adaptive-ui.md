# Internal UI Contract: Auth Screens Responsive Redesign

## Purpose

Define the internal application/UI contract for (a) `AdaptiveBody`'s new
configurable activation threshold and (b) the 4 Auth screens' width-cap and
keyboard-submission behavior. This is an internal Flutter application
contract, not a public HTTP API. This feature is presentation-layer only —
see "Gateway Contracts" below.

## Gateway Contracts

**None new.** This feature reads no repository, no database, no network
call it did not already read before. Each screen's existing
`authRepositoryProvider`/`biometricLoginRepositoryProvider` reads are
unchanged in both call shape and call site (FR-006) — only the view code
around them gains a width cap and focus wiring.

## Presentation Contracts

### `AdaptiveBody` (existing widget, extended)

- **Input** (new parameter added; all others unchanged from
  `adaptive-layout-foundation`'s contract):
  - `child` (unchanged) — the screen's main content column.
  - `maxWidth` (unchanged) — defaults to `AppLayoutTokens.contentMaxWidth`
    (960dp).
  - `activatesAt` (**new**) — a `WindowSizeClass`, defaulting to
    `WindowSizeClass.expanded` (840dp), preserving today's exact behavior
    for `AdaptiveBody`'s existing 2 callers (`overview_screen.dart`,
    `report_screen.dart`) with zero code change required at those call
    sites.
- **Output states** (generalized from the prior feature's fixed-840dp
  table):
  | Window width vs. `activatesAt` | Behavior |
  |---|---|
  | below `activatesAt`'s threshold | passthrough — `child` unchanged, full available width |
  | at/above `activatesAt`'s threshold | `child` centered, capped at `maxWidth` |
- **Used by** (this feature adds 4 new callers to the existing 2):
  | Caller | `activatesAt` | `maxWidth` |
  |---|---|---|
  | `overview_screen.dart` (existing, unchanged) | `expanded` (840dp, default) | `contentMaxWidth` (960dp, default) |
  | `report_screen.dart` (existing, unchanged) | `expanded` (840dp, default) | `contentMaxWidth` (960dp, default) |
  | `sign_in_screen.dart` (new) | `medium` (600dp) | `authContentMaxWidth` (450dp) |
  | `sign_up_screen.dart` (new, wraps scrollable body only, not header) | `medium` (600dp) | `authContentMaxWidth` (450dp) |
  | `forgot_password_screen.dart` (new, wraps `Scaffold.body`, not `AppBar`; both submitted/unsubmitted branches) | `medium` (600dp) | `authContentMaxWidth` (450dp) |
  | `reset_password_screen.dart` (new, wraps `Scaffold.body`, not `AppBar`) | `medium` (600dp) | `authContentMaxWidth` (450dp) |

### `AppLayoutTokens.authContentMaxWidth` (new constant)

- **Value**: `450` (logical pixels / dp).
- **Purity**: a `static const double`, no side effects, alongside the
  existing `contentMaxWidth = 960`.

### Enter-to-submit wiring (new, per screen)

- **Input**: keyboard focus on one of a screen's text fields, plus an
  Enter/Done keyboard action (`TextInputAction.next` or `.done`).
- **Output**:
  | Field position | `textInputAction` | On Enter |
  |---|---|---|
  | Not the last field in the form | `.next` | `FocusScope.of(context).nextFocus()` — advances to the next field in visual order |
  | Last field in the form | `.done` (Flutter's existing default) | calls the screen's existing `_submit()` **only if `_canSubmit` is true** — never unconditionally |
- **Guard contract (blocking — research.md Decision 3)**: each screen's
  existing inline button-disable predicate (e.g. Sign In's
  `_isSubmitting`; Sign Up's `_isSubmitting || !_termsAccepted`; Reset
  Password's `_isSubmitting || _succeeded`) MUST be extracted into a
  private `bool get _canSubmit` getter and consumed by BOTH the submit
  button's `onPressed` (`onPressed: _canSubmit ? _submit : null`) AND the
  last field's `onSubmitted` (`onSubmitted: (_) { if (_canSubmit)
  _submit(); }`) — a bare `onSubmitted: (_) => _submit()` with no guard is
  explicitly NOT this contract; it would let Enter bypass Sign Up's terms
  checkbox and double-submit Reset Password during its post-success delay.
- **Identity contract**: Enter on the last field MUST trigger the exact
  same code path, under the exact same gating condition, as tapping the
  primary submit button — no parallel/duplicated submit logic or guard
  logic is introduced (FR-006, FR-009).
- **Per-screen last field**: Sign In → password; Sign Up → confirm
  password; Forgot Password → email (pre-submit branch only — the
  post-submit confirmation branch has no field); Reset Password → confirm
  password.

### Tab order (verification only, no new contract surface)

- **Input**: Tab/Shift+Tab keyboard navigation on any of the 4 screens.
- **Output**: focus visits every interactive control (fields, buttons,
  Sign Up's terms checkbox) in the same top-to-bottom order the screen
  displays them — this is Flutter's existing default
  `FocusTraversalGroup`/`ReadingOrderTraversalPolicy` behavior for a
  single-column `Column` layout, unchanged by this feature's code; FR-008's
  test coverage verifies this holds, it does not introduce new traversal
  logic.

## Error Contract

**None new.** `AdaptiveBody`'s extended form cannot fail for any realistic
input (the new `activatesAt` parameter is a plain enum value, not a
computation that can throw). Enter-to-submit calls each screen's existing
`_submit()`, which already has its own try/catch/error-message handling —
this feature adds no new error path, only a new trigger for the existing
one.

## Navigation Contract

**None new.** Zero new routes/paths. The 4 existing Auth routes
(`/sign-in`, `/sign-up`, `/forgot-password`, and the reset-password deep-
link-only route) are unchanged; Enter-to-submit's navigation-on-success
behavior (e.g. Sign In → app shell, Reset Password → `/sign-in` after its
existing 2-second delay) is identical to today's button-tap path, since
both call the same `_submit()`.
