# Feature Specification: Auth Screens Responsive Redesign

**Feature Branch**: `20260925-204837-auth-screens-responsive`

**Created**: 2026-09-25

**Status**: Draft

**Input**: User description: "Redesign the Auth screens (4 screens: Sign In,
Sign Up, Forgot Password, Reset Password — one combined spec) following the
research the user and Claude already did."

## Clarifications

### Session 2026-09-25

- Q: FR-003 left the auth content max-width as an unresolved ~440–480dp
  range from prior research (which turned out to have no real Material
  Design sourcing — corrected during this session). Should the spec commit
  to one exact value now, and if so, which? → A: 560dp — Material's actual,
  sourced max-width figure for dialogs (min 280dp / max 560dp, consistent
  across Material 2 and 3), chosen over the uncited ~440–480dp range once
  that range was found to have no real spec backing.
- Q: Follow-up — is 560dp (or the earlier 480dp) actually a *commonly used*
  auth-form width in real shipped products, independent of what any one
  design system's spec says? → A: No — researched across Bootstrap
  (official Sign-in template: 330px), MUI (official Sign-in template:
  450px; `Container maxWidth="xs"`: 444px), Tailwind (`max-w-md`: 448px,
  used by shadcn/ui's login blocks), and Ant Design (~300px): the real
  common cluster for auth-form width across popular frameworks is
  **330–450px**, distinctly lower than both 480dp and 560dp. 560dp remains
  a real Material dialog figure, but dialogs and full-page auth forms are a
  different UI pattern — the width guidance doesn't transfer. Superseding
  the previous answer: the max-width is changed to **450dp**, matching
  MUI's own official Sign-in template and sitting at the upper (roomier)
  end of the observed 330–450dp common range.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Auth forms stay readable at any window width (Priority: P1)

A user opens Sign In, Sign Up, Forgot Password, or Reset Password on a wide
window (a tablet, a desktop browser, or a resized web window). Today, the
form control stretches edge-to-edge — on a wide window, input fields become
implausibly long and the visual distance between a label and its neighboring
field on either side grows uncomfortably wide. Instead, the form should stay
at a comfortable, letter-sized reading width and sit centered in the
available space, exactly as the app's existing dashboard screens (Tổng
quan, Báo cáo) already center their own content instead of stretching it.

**Why this priority**: This is the single defect referenced by all four
screens and the only one with a concrete visual symptom named in this
feature's own research (`responsive-explainer` artifact: "form kéo giãn hết
chiều rộng màn hình, đặt trong SingleChildScrollView"). It is also the
smallest, lowest-risk change of the two stories — a width cap and centering,
no restructuring — making it the safe stopping point if this feature's
budget is cut after P1 alone (mirrors FR-008's stop-after-any-tier pattern
from the most recent shipped feature).

**Independent Test**: Open each of the 4 screens at a window width at or
above 600dp (medium window size class or wider). The form content is capped
at a fixed maximum width and horizontally centered; at any width below
600dp, each screen renders pixel-for-pixel identically to its current
mobile layout.

**Acceptance Scenarios**:

1. **Given** the Sign In screen open in a window ≥600dp wide, **When** the
   screen renders, **Then** the logo block, identifier/password fields, and
   submit button are capped at the shared auth content width and centered
   in the window, with empty space visible on both sides.
2. **Given** any of the 4 screens open in a window <600dp wide (a phone),
   **When** the screen renders, **Then** its layout, spacing, and every
   visual element match today's behavior exactly — no width cap applies.
3. **Given** any of the 3 screens with a header bar above its scrollable
   form (Sign Up, Forgot Password, Reset Password), **When** the window is
   ≥600dp wide, **Then** the header bar spans the full window width
   unchanged (matching the app shell convention already used elsewhere)
   while only the scrollable form body below it is width-capped and
   centered.
4. **Given** any screen at ≥600dp wide, **When** the window is resized
   narrower past the 600dp boundary while the screen is on-screen, **Then**
   the layout switches between capped/centered and full-width live, with no
   loss of in-progress field text, scroll position, or error/success message
   state.

---

### User Story 2 - Auth forms are usable with mouse and keyboard, not just touch (Priority: P2)

A user reaches an Auth screen on a platform where a mouse and keyboard are
available (a web browser, or a touch platform with a keyboard/mouse
attached) — most commonly by opening Sign In as the cold-start landing
screen of a fresh web session, or navigating to Sign Up/Forgot Password from
there. Today, every interactive control on these 4 screens is built and
verified only for touch: text fields show no hover state, icon-only buttons
(the password show/hide eye icon) carry a tooltip already but other
icon-only controls may not, and there is no verified tab order across
fields. This story brings the 4 screens in line with the constitution's
existing "Adaptive Layout" requirement (already enforced on other screens),
which the screens predate.

**Why this priority**: Lower priority than P1 because it has no reported
visual defect today (this is closing a latent gap against a standing
constitution rule, not fixing something a user noticed) and Auth is not the
first screen most users see repeatedly — Overview/Home is. It still matters
because Auth is the one screen every web user is guaranteed to pass through
at least once (cold-start sign-in), making it a meaningful place for
keyboard/mouse users to notice the gap.

**Why not P1**: Splitting from User Story 1 keeps the layout fix (highest
value, lowest risk) shippable and reviewable on its own, per this
project's established tiering pattern.

**Independent Test**: On any of the 4 screens, using only Tab/Shift+Tab and
Enter (no mouse/touch), reach and activate every interactive control in a
logical order; hover a mouse over each text field and icon-only button and
observe a visible hover/focus indication.

**Acceptance Scenarios**:

1. **Given** the Sign In screen with a mouse available, **When** the user
   hovers over the identifier field, the password field, or the
   show/hide-password icon button, **Then** each shows a visible hover
   state (already Flutter's default `TextField`/`IconButton` behavior once
   not suppressed — this scenario is a verification, not necessarily a code
   change).
2. **Given** any of the 4 screens with a keyboard available, **When** the
   user presses Tab repeatedly from the first field, **Then** focus visits
   every field and button in the same top-to-bottom order the screen
   displays them, with a visible focus ring on each, and Enter on the final
   field submits the form the same as tapping its submit button.
3. **Given** the Sign In screen's password field, **When** it has keyboard
   focus, **Then** pressing Enter submits the form (parity with tapping
   "Đăng nhập"), matching this project's existing expectation that a
   primary action is keyboard-activatable once reachable off a touch-only
   platform.

---

### Edge Cases

- **Forgot Password's two states** (request form vs. confirmation message):
  both states MUST be width-capped and centered identically at ≥600dp — the
  confirmation message is not exempt just because it has no input field.
- **Reset Password's transient states** (inline error message, inline
  success message before the 2-second auto-redirect to Sign In): both
  states MUST render inside the same capped/centered container as the base
  form — the container must not visibly resize or jump when an error or
  success message appears/disappears.
- **Sign Up's long form** (5 fields + terms checkbox) at ≥600dp: the field
  stack MUST remain a single vertical column inside the capped width — this
  feature does not introduce a multi-column form layout (Assumptions).
- **Very narrow desktop/web windows** (e.g. a web browser window
  deliberately resized to ~500dp, still "desktop" but below the 600dp
  breakpoint): MUST render the existing compact/mobile layout, per the
  constitution's "driven by window size, never device type" rule — there is
  no separate "narrow desktop" treatment.
- **The Sign In screen's dual role** (also reachable as the app-lock
  re-entry gate per its existing code comment, with the biometric button
  conditionally visible): the width cap and centering apply identically
  regardless of which entry path led here — this feature does not change
  when the biometric button shows or hides.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: All 4 Auth screens (Sign In, Sign Up, Forgot Password, Reset
  Password) MUST cap their form content at a fixed maximum width and center
  it horizontally within the window once the window reaches the medium
  window size class (600dp) or wider, per the constitution's Adaptive
  Layout principle.
- **FR-002**: Below the 600dp breakpoint, every one of the 4 screens MUST
  render identically (layout, spacing, sizing, colors, copy) to its current
  behavior — this feature MUST NOT change anything about the existing
  mobile/compact experience.
- **FR-003**: The auth content max-width MUST be a single shared value —
  **450dp** — reused by all 4 screens (no screen invents its own number),
  analogous to how `AppLayoutTokens.contentMaxWidth` already centralizes
  the dashboard screens' own width cap, but defined as its own, narrower,
  dedicated token rather than reusing `contentMaxWidth` (960dp), since a
  form-shaped screen and a dashboard-shaped screen have different
  comfortable widths (Clarifications: 450dp matches MUI's own official
  Sign-in template and sits at the upper end of the ~330–450dp common range
  observed across popular frameworks' auth-form templates).
- **FR-004**: On the 3 screens with a header bar above their scrollable
  content (Sign Up's custom header row; Forgot Password's and Reset
  Password's `AppBar`), that header bar MUST remain full-window-width at
  every window size; only the scrollable form body below it is subject to
  FR-001's width cap and centering. (Sign In has no separate header bar —
  its logo block is itself part of the width-capped content.)
- **FR-005**: The width-cap/centering behavior MUST be driven only by
  window size (`MediaQuery`/`LayoutBuilder`), never by `Platform.is*`,
  `kIsWeb`, or `defaultTargetPlatform`, per the constitution's Adaptive
  Layout principle.
- **FR-006**: This feature MUST NOT change any business logic, validation
  rule, error message, network call, or navigation destination on any of
  the 4 screens — every existing behavior (biometric sign-in/enrollment
  prompt, duplicate-email handling, generic forgot-password confirmation
  regardless of outcome, reset-password's 2-second auto-redirect, terms
  checkbox gating the Sign Up submit button, etc.) MUST be preserved
  exactly as today.
- **FR-007**: Every text field and icon-only interactive control on the 4
  screens MUST show a visible hover indication when a mouse is available,
  per the constitution's Adaptive Layout principle (Assumptions: expected
  to already hold via Flutter's un-suppressed defaults; this feature MUST
  verify this holds and fix any place it does not).
- **FR-008**: Every interactive control on the 4 screens (text fields,
  buttons, checkbox, icon buttons) MUST be reachable via Tab/Shift+Tab in
  the same order the screen visually displays them, with a visible focus
  indicator, on any platform where a keyboard is available.
- **FR-009**: On each of the 4 screens, pressing Enter while any of that
  screen's text fields has keyboard focus MUST trigger the same action as
  tapping that screen's primary submit button (Sign In / Sign Up / Forgot
  Password / Reset Password).
- **FR-010**: A window resize across the 600dp boundary while an Auth
  screen is on-screen MUST NOT clear any in-progress field text, scroll
  position, or visible error/success message.

### Key Entities

*(N/A — this feature introduces no new data entity; it is a layout-only
change to 4 existing screens.)*

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On a window ≥600dp wide, all 4 Auth screens display their form
  content capped at 450dp width (not stretched to the window's full width),
  verified visually on at least one window size in each of the medium,
  expanded, and large window size classes.
- **SC-002**: On a window <600dp wide, all 4 Auth screens are visually
  indistinguishable from their current (pre-this-feature) behavior — zero
  regressions to the existing, already-shipped mobile experience.
- **SC-003**: Every interactive control on all 4 screens is operable using
  only a keyboard (Tab, Shift+Tab, Enter) — no control is reachable only by
  mouse/touch.
- **SC-004**: The full existing automated test suite continues to pass at
  100% (428/428 at this feature's start) with zero regressions, plus new
  tests covering this feature's own width-cap and keyboard-operability
  requirements.

## Assumptions

- **Auth content max-width value**: resolved to 450dp during clarification
  (Clarifications) — this went through two corrections in sequence: the
  original ~440–480dp research figure had no real Material Design citation
  behind it; the first fix (560dp) was a real Material figure but for
  dialogs, not full-page forms; the final value, 450dp, matches MUI's own
  official Sign-in template and the observed ~330–450dp common range across
  popular frameworks' actual auth-form widths. FR-003 defines it as a
  single shared, dedicated token distinct from the dashboard's 960dp.
- **List-detail pattern does not apply here**: unlike Lịch sử giao dịch (a
  natural list-detail candidate per this feature's own prior research), Auth
  screens are single forms with no list of items to browse — this feature's
  redesign is width-capping and centering only, not a structural layout
  change.
- **No new visual design**: this feature reuses the 4 screens' existing
  colors, typography, spacing, and copy exactly — only the outer width
  constraint and (per User Story 2) verified input-affordance behavior
  change. There is no new mockup or visual identity introduced.
- **Hover/focus is mostly verification, not new code**: per FR-007's own
  wording, Flutter's default `TextField`/`IconButton`/`FilledButton` already
  provide hover and focus states unless explicitly suppressed; this feature
  assumes most of User Story 2 is confirming this holds today and fixing
  specific gaps found, not building hover/focus support from scratch.
- **Desktop native is out of scope**: this feature is about window-size
  responsiveness (phone vs. wide window), which applies on every currently
  supported platform (Android, iOS, Web) — it does not require, assume, or
  add Windows/macOS/Linux platform support, which remains deferred per the
  constitution's Multi-Platform Support section.
- **Reuses existing breakpoint infrastructure**: this feature consumes the
  `WindowSizeClass`/`windowSizeClassFor` tokens already defined in
  `core/theme/app_layout.dart` (from `adaptive-layout-foundation`) rather
  than redefining breakpoint numbers.
