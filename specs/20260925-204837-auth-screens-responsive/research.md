# Phase 0 Research: Auth Screens Responsive Redesign

## Decision 1: Extend `AdaptiveBody` with a configurable activation threshold, not a second widget

**Decision**: Add a constructor parameter to the existing
`lib/core/widgets/adaptive_body.dart` (e.g. `activatesAt:
WindowSizeClass`, defaulting to `WindowSizeClass.expanded` to preserve
today's behavior for its existing 2 callers) so the compact/medium
early-return branch becomes configurable per caller instead of hardcoded
to `expanded` (840dp). The 4 Auth screens pass `activatesAt:
WindowSizeClass.medium` (600dp) and `maxWidth:
AppLayoutTokens.authContentMaxWidth` (Decision 2).

**Rationale**: Reading `adaptive_body.dart:27-31` found a real mismatch,
not a hypothetical one:

```dart
final widthClass = windowSizeClassFor(MediaQuery.sizeOf(context).width);
if (widthClass == WindowSizeClass.compact ||
    widthClass == WindowSizeClass.medium) {
  return child;
}
```

`AdaptiveBody` today only starts capping/centering at `expanded` (840dp) —
confirmed both by this code and by its own test
(`test/widget/core/widgets/adaptive_body_test.dart:41-49`, "at 840dp
exactly... child still fills the available width — the cap has not started
binding yet") and its own doc comment ("centers it once the window reaches
`WindowSizeClass.expanded` (840dp)"). spec.md FR-001 requires the Auth cap
to start at `medium` (600dp). Passing only a different `maxWidth` to the
existing widget as-is would silently leave a 600–839dp gap where Auth forms
would still stretch uncapped — a real defect if unaddressed, not a
theoretical one.

Extending the same widget (over building a second one) keeps
width-cap/center mechanics defined in exactly one place, consistent with
why `AdaptiveBody` was promoted to `core/widgets/` in the first place (its
own doc comment: "because it has two consumers from its first commit... 
meeting the constitution's `core/` only once ≥2 features/screens need it
bar"). Gaining 4 more consumers with a second, different threshold need is
exactly the kind of variation `core/` code should absorb via configuration,
not the kind that justifies a parallel implementation.

**Alternatives considered**:
- **Build a separate `AuthBody` widget** duplicating the `Center` +
  `ConstrainedBox` shape, branching only on `compact`. Rejected: two
  widgets doing the same `Center`/`ConstrainedBox` mechanics with different
  thresholds is exactly the kind of small-duplication-that-should-be-one-
  parameter the constitution's Code Quality principle discourages, and it
  fragments any future change to the capping mechanic itself (e.g. a
  different centering strategy) across two files.
- **Inline `LayoutBuilder`/`MediaQuery.sizeOf` + `ConstrainedBox` directly
  in each of the 4 screens**, no shared widget at all. Rejected: 4x
  duplication of the same threshold-check-and-cap logic, and it stops
  being "a single shared max-width token" (FR-003's own wording) if each
  screen re-derives its own threshold check.
- **Leave `AdaptiveBody` untouched, accept the 600–839dp gap.** Rejected
  outright — this would ship FR-001 as stated false in that width range,
  not a scope trade-off worth making.

## Decision 2: `authContentMaxWidth` = 450dp, a new dedicated token

**Decision**: Add `AppLayoutTokens.authContentMaxWidth = 450` (logical
pixels) alongside the existing `contentMaxWidth = 960` in
`lib/core/theme/app_layout.dart`.

**Rationale**: Resolved during `/speckit-clarify` (see spec.md
Clarifications) after two corrections in sequence: the original ~440–480dp
research figure had no real Material Design citation; a first correction
to 560dp used a real Material figure but for dialogs specifically, not
full-page forms (Material has no documented "form width" guidance at all);
the final value, 450dp, matches MUI's own official Sign-in template and
sits at the upper end of the ~330–450dp common range observed across
popular frameworks' actual shipped auth-form widths (Bootstrap 330px, MUI
444–450px, Tailwind `max-w-md` 448px). A dedicated token — not a reuse of
`contentMaxWidth` (960dp) — because a 2–7-field vertical form and a
multi-card dashboard have different comfortable widths, and FR-003
explicitly requires this feature not invent a per-screen number.

**Alternatives considered**:
- **Reuse `contentMaxWidth` (960dp) directly.** Rejected: FR-003 explicitly
  rules this out — 960dp on a 2-field Sign In form would visually
  underserve the "comfortable reading width" this feature exists to
  deliver; the dashboard token's own doc comment already anticipates this
  ("later, differently-shaped screens... may introduce their own constant
  here").
- **330dp (Bootstrap's figure) or 560dp (Material's dialog figure).**
  Rejected during clarification — 330dp is at the narrow end of the
  observed range (Sign Up's 5-field form plus terms checkbox would feel
  cramped at the narrowest common value), and 560dp measures a different
  UI pattern (dialog, not full-page form) whose width guidance doesn't
  transfer, per the same clarification session's research.

## Decision 3: Enter-to-submit and Tab order — minimal, view-layer-only wiring

**Decision**: For each of the 4 screens, add one `FocusNode` per text field
(none exist today — confirmed via grep across all 4 files, zero matches).
Intermediate fields get `textInputAction: TextInputAction.next` and
`onSubmitted: (_) => FocusScope.of(context).nextFocus()`; each screen's
LAST field gets `textInputAction: TextInputAction.done` (already Flutter's
default, so unchanged) and `onSubmitted: (_) => _submit()` — but gated
through the exact same predicate that already disables that screen's
`FilledButton.onPressed`, not called unconditionally. Concretely: each
screen's existing inline `onPressed: <predicate> ? null : _submit` guard
(e.g. `sign_in_screen.dart:230`'s `_isSubmitting ? null : _submit`,
`sign_up_screen.dart:223-225`'s `(_isSubmitting || !_termsAccepted) ? null
: _submit`, `reset_password_screen.dart:131`'s `(_isSubmitting ||
_succeeded) ? null : _submit`) is extracted into a private `bool
get _canSubmit` getter on that screen's State class, and BOTH the button's
`onPressed` and the last field's `onSubmitted` call through it: `onPressed:
_canSubmit ? _submit : null` and `onSubmitted: (_) { if (_canSubmit)
_submit(); }`. `FocusNode`s are created/disposed alongside each screen's
existing `TextEditingController`s, in the same `initState`/`dispose`
lifecycle already present. Tab order itself needs no explicit wiring — it
is already automatic via Flutter's default `FocusTraversalGroup`
(`ReadingOrderTraversalPolicy`), which matches visual/widget-tree order for
these screens' simple top-to-bottom `Column` layouts; this feature's own
FR-008 test coverage is a verification, not new traversal-ordering code.

**Why the guard matters (not just style)**: an initial version of this
decision wired `onSubmitted: (_) => _submit()` directly, bypassing each
button's existing guard. That would have been a real FR-006 violation, not
a hypothetical one — concretely, on **Sign Up**, `_submit()` itself
performs no terms-checkbox check (only field-validation checks,
`sign_up_screen.dart:57-77`); the checkbox only gates the *button* via
`(_isSubmitting || !_termsAccepted) ? null : _submit` at the call site. An
ungated `onSubmitted` would let Enter submit Sign Up with the terms
checkbox unchecked — directly contradicting spec.md FR-006's explicit
"terms checkbox gating the Sign Up submit button... MUST be preserved
exactly as today." On **Reset Password**, an ungated `onSubmitted` would
also allow a second submission during the 2-second window between success
(`_succeeded = true`) and the auto-navigate to `/sign-in`
(`reset_password_screen.dart:131`'s `_succeeded` guard). On **Sign In**/
**Forgot Password**, it would allow a rapid double-submit while
`_isSubmitting` is already true. Routing both entry points through one
`_canSubmit` getter (rather than duplicating each predicate inline in two
places) also avoids the predicate silently drifting out of sync between
the button and the field if either is edited later.

Per-screen field order confirmed for scope-sizing (this list is descriptive
context for planning/tasks, not new spec content):
- **Sign In**: identifier → password (→ Enter submits).
- **Sign Up**: name → phone → email → password → confirm password (→ Enter
  submits). Terms checkbox and every button stay outside this chain — only
  text fields need a `FocusNode` for Enter-to-submit; Tab still reaches the
  checkbox/buttons via the same automatic traversal.
- **Forgot Password**: email (→ Enter submits). Post-submit confirmation
  branch has no field, out of scope for this wiring.
- **Reset Password**: new password → confirm password (→ Enter submits).

**Rationale**: This is the one place spec.md's User Story 2 is not "just
verification" — grepping confirmed zero `onSubmitted`/`textInputAction`
usage anywhere in the 4 files today, so pressing Enter in any field
currently only dismisses the keyboard (Flutter's `EditableText` default
`_finalizeEditing(shouldUnfocus: true)` behavior for the implicit
`TextInputAction.done`), never submits. The pattern above is the standard,
minimal Flutter idiom for this — no `Form` widget wrapping needed (none of
the 4 screens use one today, and introducing one is out of scope per
FR-006's no-business-logic-change constraint; this wiring is pure focus/
input-action plumbing, calling each screen's pre-existing `_submit`
unchanged). Calling the same `_submit` the button already calls (not a
new/duplicated method) keeps this from becoming a second source of
submit-logic truth.

**Alternatives considered**:
- **Wrap each screen's fields in a `Form` widget** with
  `Form.autovalidateMode`/`GlobalKey<FormState>`. Rejected: none of the 4
  screens validate via `Form`/`FormField` today (Sign Up does its own
  manual field-level error-state checks in `_submit`, e.g.
  `sign_up_screen.dart:57-77`); introducing `Form` here would touch how
  validation is structured, which FR-006 explicitly forbids for this
  feature.
- **Rely on `TextInputAction.next`'s "automatic" default field-advance
  without an explicit `FocusScope.of(context).nextFocus()` call.**
  Rejected: Flutter's default `TextInputAction` is `.done` for every
  single-line field regardless of position — it does not auto-infer "next
  field" from being followed by another field without both the explicit
  `textInputAction: .next` AND an `onSubmitted` (or `Form`-mediated)
  handler advancing focus; leaving this implicit would silently not work.
- **Call `_submit()` directly from `onSubmitted`, ungated.** This was the
  first version of this decision and was rejected once its consequences
  were checked against each screen's actual guard logic (see "Why the
  guard matters" above) — it is a real FR-006 violation on Sign Up
  specifically (lets Enter bypass the terms-checkbox gate), plus a
  double-submit risk on Reset Password's post-success window and a
  general double-submit risk on Sign In/Forgot Password while
  `_isSubmitting` is already true. The `_canSubmit` getter, shared by both
  the button and the field, is the fix.

## Decision 4: Reuse each screen's existing widget-test harness unchanged

**Decision**: Add new `testWidgets` cases directly into the 4 existing
files (`test/widget/features/account/{sign_in,sign_up,forgot_password,
reset_password}_screen_test.dart`), reusing each file's existing `_Fake*
Repository` + `_harness()` helper exactly as-is — no new test
infrastructure, no new harness pattern.

**Rationale**: All 4 files already share one established pattern: a
private fake repository (`noSuchMethod` throwing `UnimplementedError` for
anything unstubbed) wired into a `ProviderScope` override, wrapping
`MaterialApp.router` with a real `GoRouter` stubbing the screen-under-test
route plus its immediate navigation target(s) with a trivial placeholder
`Scaffold`. This is the same "real router in test harness, not a
simplified placeholder" pattern this project's prior features (per this
session's git history) have consistently reused rather than reinvented.
This feature's new assertions (width/position via `tester.getSize`/
`tester.getTopLeft`, focus/Tab-order via `tester.sendKeyEvent`/
`FocusManager.instance.primaryFocus`, Enter-submission via
`tester.testTextInput.receiveAction(TextInputAction.done)`) all operate
within this same existing harness — no reason to diverge from it.

**Alternatives considered**:
- **Build a new shared test helper for "pump at width X" across all 4
  files**, rather than each file adapting the pattern individually.
  Considered but not required for Phase 0 — Decision 5 already identifies
  the concrete `_pumpAt`-style pattern to adapt per file; whether it's
  extracted into a shared test utility (versus duplicated 4x, matching how
  each file's `_harness()` is already file-local, not shared) is a Phase 2
  task-level call, not a research-phase architectural decision — the
  4 screens' own harnesses are already independently file-local today, so
  keeping the new width-pumping helper file-local too is consistent with
  the existing precedent unless task breakdown finds a concrete reason to
  extract it.

## Decision 5: Compact/expanded breakpoint test coverage via `tester.view.physicalSize`

**Decision**: For each of the 4 screens' new width-cap tests, pump the
widget tree at a compact width (e.g. 375 logical px) and an expanded width
(e.g. 1024 logical px) using the exact pattern already established in
`test/widget/core/widgets/adaptive_body_test.dart:9-15`:

```dart
tester.view.physicalSize = Size(width, 800);
tester.view.devicePixelRatio = 1.0;
addTearDown(() {
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
});
```

**Rationale**: This is confirmed as the modern, non-deprecated API for
this codebase's pinned Flutter version (3.41.0, `pubspec.yaml` SDK
constraint `^3.11.0` — both well past the older
`tester.binding.window.physicalSizeTestValue` API's deprecation) and is
the sole existing precedent for width-varying widget tests anywhere in
this repo. `overview_screen_test.dart` and `report_screen_test.dart` both
consume `AdaptiveBody` in production code but contain zero
`physicalSize`/`devicePixelRatio` usage (confirmed via grep) — despite
being `AdaptiveBody` consumers, they are not usable precedents for
breakpoint testing itself, only `adaptive_body_test.dart` is. Reusing this
exact pattern satisfies constitution Principle II's explicit requirement
("any screen with breakpoint-dependent layout MUST have widget or golden
coverage at both a compact (<600dp) and an expanded (≥840dp) width")
without introducing a second, divergent way of doing the same kind of test.

**Alternatives considered**:
- **`tester.binding.window.physicalSizeTestValue`** (older API). Rejected:
  deprecated relative to this project's pinned Flutter/Dart SDK versions;
  `tester.view.physicalSize` is the confirmed current replacement already
  in use in this exact codebase.
- **Golden/screenshot tests** instead of widget-tree assertions. Not
  pursued for this feature's primary coverage — constitution Principle II
  frames golden tests as a SHOULD ("for widgets where pixel-level
  regressions matter (charts, balance summaries)"), not a MUST, and this
  feature's assertions (a capped width, a centered position, a focus
  target after Enter) are precisely checkable via `tester.getSize`/
  `tester.getTopLeft`/`FocusManager` without needing pixel-level golden
  comparison.
