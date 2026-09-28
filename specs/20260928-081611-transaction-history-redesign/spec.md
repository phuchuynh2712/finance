# Feature Specification: Transaction History Screen Responsive Redesign

**Feature Branch**: `20260928-081611-transaction-history-redesign`

**Created**: 2026-09-28

**Status**: Draft

**Input**: User description: "Redesign lại màn hình Lịch sử giao dịch theo nghiên cứu tôi và bạn đã làm"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - History list stays readable at any window width (Priority: P1) 🎯 MVP

A user opens Transaction History on a wide window (a tablet, a desktop
browser, or a resized web window). Today the header, month/filter controls,
and the transaction list all stretch edge-to-edge no matter how wide the
window gets, so entries become very long single-line rows with a large gap
between the item name and its amount — harder to scan than on a phone.

**Why this priority**: This is the same "content must not stretch unbounded"
gap already fixed for the Auth screens and for Home Overview / Monthly
Report — Transaction History is the one remaining unstyled screen with this
issue, and it is reached from multiple places in the app (Overview's "see
all", Overview's negative-balance link, Expense Control), so the gap is
visible on every one of those paths.

**Independent Test**: Open Transaction History at a window ≥840dp and
confirm the header, month/filter controls, and transaction list are all
capped at the shared content max-width and centered, with visible space on
both sides; open at <840dp and confirm pixel-for-pixel match with today's
behavior; resize live across 840dp mid-scroll and confirm scroll position
and the currently-selected month/filter are preserved.

**Acceptance Scenarios**:

1. **Given** the window is ≥840dp wide, **When** Transaction History is
   open, **Then** the month/filter controls and the transaction list render
   inside a container capped at the shared content max-width, centered
   horizontally, with the screen's own background visible on both sides.
2. **Given** the window is <840dp wide, **When** Transaction History is
   open, **Then** every control and list row renders exactly as it does
   today, edge-to-edge with no cap applied.
3. **Given** the window is ≥840dp and the user has scrolled partway down a
   month with several transactions, **When** the window is resized to
   <840dp, **Then** the scroll position, the selected month, and the
   selected filter chip are all unchanged.
4. **Given** an ultra-wide window (well beyond the point the cap first
   binds), **When** Transaction History is open, **Then** the content
   width stops growing at the cap — it does not keep expanding with the
   window.

---

### User Story 2 - History screen is usable with mouse and keyboard, not just touch (Priority: P2)

A user reaches Transaction History on a platform where a mouse and keyboard
are available (web, desktop, or a touch device with a keyboard attached).
Today every interactive control (back button, previous/next-month buttons,
filter chips, the retry button on a load error) only has touch-sized hit
areas with no visible hover or keyboard-focus indication, and there is no
way to reach or activate any of them without touching the screen.

**Why this priority**: Same category of gap as Auth screens' User Story 2 —
it does not block anyone using the screen by touch (hence P2, not P1), but
it is a real gap on desktop/web where a pointer and keyboard are the primary
input method.

**Independent Test**: Tab through the screen and reach/activate the back
button, both month-navigation buttons, every filter chip, and (when an
error state is showing) the retry button — all in visual order; hover each
of those controls with a mouse and observe a visible indication; activate
each control via keyboard (Enter/Space) and confirm it does exactly what
tapping it would.

**Acceptance Scenarios**:

1. **Given** the screen has loaded, **When** the user presses Tab
   repeatedly starting from the back button, **Then** focus visits the
   back button, the previous-month button, the next-month button, every
   filter chip in the order they are shown, and — when a load error is
   showing instead of the list — the retry button, with a visible focus
   indicator at every stop.
2. **Given** a mouse is available, **When** the user hovers any of those
   controls, **Then** a visible hover state appears (matching this app's
   existing hover treatment for buttons and chips elsewhere).
3. **Given** a filter chip has keyboard focus, **When** the user presses
   Enter or Space, **Then** that filter is applied exactly as tapping the
   chip would.
4. **Given** the next-month button is disabled (the selected month is the
   current month), **When** the user tabs to it, **Then** it is skipped or
   shown as clearly non-interactive, and activating it does nothing.

---

### Edge Cases

- What happens to the loading state (fetching a newly-selected month), the
  empty state (no transactions this month), and the error state (load
  failed) at a wide window? All three MUST also render inside the capped,
  centered container — not full-width — so the screen does not look
  inconsistent depending on which state is showing (mirrors the Auth
  screens' requirement that pre- and post-submit states both respect the
  cap).
- What happens to the horizontally-scrolling filter-chip row at a wide
  window? It stays a horizontally-scrolling row inside the capped container
  — it does not reflow into a wrapped/multi-line layout, since the existing
  chip row already handles overflow via horizontal scroll and changing that
  behavior is out of scope for this feature.
- What happens when a screen reader is used at a wide window? Every
  existing `Semantics` label (rows, buttons, chips) is unaffected — this
  feature only changes visual width and keyboard/hover support, never
  removes or alters accessibility labels.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The month/filter controls and the transaction list (including
  its loading, error, and empty states) MUST be capped at a shared content
  max-width and centered once the window reaches the `expanded` breakpoint
  (840dp) or wider, matching the same width-cap mechanism already used by
  Home Overview and Monthly Report.
- **FR-002**: Below the `expanded` breakpoint (840dp), every element on
  this screen MUST render pixel-for-pixel identical to its current,
  unmodified behavior.
- **FR-003**: The header bar (back button, title) MUST remain full-width at
  every window size — only the scrollable body below it is capped,
  matching how Sign Up / Forgot Password / Reset Password keep their
  header bars full-width while capping only the form body.
- **FR-004**: Resizing the window live, at any scroll position, MUST NOT
  reset scroll position, the selected month, or the selected filter.
- **FR-005**: The width cap MUST be driven only by window size — it MUST
  NOT branch on platform or device type.
- **FR-006**: Every interactive control on this screen (back button,
  previous/next-month buttons, filter chips, retry button) MUST be
  reachable via Tab in visual order, with a visible keyboard-focus
  indicator.
- **FR-007**: Every interactive control on this screen MUST show a visible
  hover state when a mouse is available.
- **FR-008**: Every interactive control on this screen MUST be activatable
  via keyboard (Enter or Space), performing exactly the same action as a
  tap.
- **FR-009**: A disabled control (the next-month button when the selected
  month is the current month) MUST NOT be activatable via keyboard, and
  MUST be clearly indicated as non-interactive when it holds focus.

### Key Entities

*(This feature changes layout and input handling only — it introduces no
new data, and reuses every entity, provider, and repository method this
screen already depends on unmodified.)*

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On a window ≥840dp wide, the month/filter controls and the
  transaction list (in every state: loading, populated, empty, error)
  render inside a capped, centered container in 100% of manual and
  automated checks across the `expanded`, `large`, and `extra-large`
  breakpoints.
- **SC-002**: On a window <840dp wide, automated regression tests confirm
  zero visual or behavioral difference from the screen's pre-feature state.
- **SC-003**: Every interactive control on the screen is reachable and
  activatable by keyboard alone, verified by an automated traversal test
  that reaches 100% of the screen's interactive controls.
- **SC-004**: A live resize across the 840dp threshold, performed at any
  scroll position with any month/filter selected, never changes that
  scroll position, month, or filter — verified by an automated test.
- **SC-005**: Every interactive control on the screen shows a visible hover
  indication when a mouse is available, verified by an automated check for
  a wired hover-detection mechanism on 100% of the screen's interactive
  controls.

## Assumptions

- The shared content max-width token and breakpoint-activation mechanism
  already introduced for Home Overview / Monthly Report / the Auth screens
  (`AdaptiveBody`, `AppLayoutTokens.contentMaxWidth`,
  `WindowSizeClass.expanded`) are reused as-is — this feature does not
  introduce a new width value or a new activation threshold, since
  Transaction History is a list/dashboard-shaped screen like Overview and
  Report, not a narrow form like the Auth screens (which use a separate,
  narrower `authContentMaxWidth` activated at the `medium` breakpoint).
  **Revised during planning**: while the *values* (token, threshold) are
  reused as-is, verifying FR-004 (scroll position preserved across a live
  resize) against `AdaptiveBody`'s actual implementation surfaced a real,
  previously-undetected bug — crossing the activation threshold reset any
  State (scroll position included) living inside the wrapped content. This
  is now understood to be a pre-existing defect in the shared widget, not a
  gap specific to this feature, and is fixed at its root as part of this
  feature's own scope (see plan.md's Scope note and research.md Decision
  1a) — this feature's boundary is therefore layout/input handling for
  Transaction History **plus** this one root-cause fix to `AdaptiveBody`,
  not Transaction History alone.
- "Reachable from multiple places in the app" (Overview's "see all",
  Overview's negative-balance link, Expense Control) means this feature's
  navigation entry points are unchanged — only the screen's own internal
  layout and input handling are in scope.
- No new interactive control is added by this feature — FR-006 through
  FR-009 only extend keyboard/hover/focus support to the controls that
  already exist on this screen today (back button, month buttons, filter
  chips, retry button); the individual transaction rows themselves stay
  non-interactive (tapping a row today does nothing, and this feature does
  not change that).
- The retry button's keyboard/hover support (FR-006–FR-008) only needs to
  be verified in the error state, since that is the only state in which it
  renders.
