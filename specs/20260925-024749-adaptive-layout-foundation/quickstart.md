# Quickstart: Adaptive Layout Foundation Verification

## Prerequisites

- Run from the repository root with Flutter dependencies available
  (`flutter pub get`).
- A signed-in test user (any account) — this feature is presentation-only
  and does not depend on specific transaction/budget data, but Tổng quan
  and Báo cáo should have at least a little data so their content is tall
  enough to show the max-width capping meaningfully.
- A way to view the app at more than one window width: a resizable
  desktop/web browser window is the fastest way to check the *live-resize*
  scenarios; a phone-width emulator/device and a tablet/desktop-width one
  cover the rest.

## Verification Flow

1. **Compact width unchanged** — open the app at a width narrower than
   600dp (a phone). Confirm the bottom navigation bar looks and behaves
   exactly as it did before this feature (5 destinations, icon+label,
   selection, the Kiểm soát unsaved-edits prompt) — no regression
   (FR-001, FR-004, Acceptance Scenario 1).
2. **Rail at ≥600dp** — open (or resize) the app to 600dp or wider.
   Confirm navigation is now a side rail with the same 5 destinations,
   each showing its icon **and** text label (not icon-only — Clarification
   Q1), and whichever tab was selected stays selected (Acceptance
   Scenario 2).
3. **Unsaved Kiểm soát edits, from the rail** — with an unsaved formula
   edit pending on Kiểm soát at ≥600dp width, select a different rail
   destination. Confirm the same save/discard/cancel prompt appears as it
   does today from the bottom bar, and each choice behaves identically
   (FR-004, Acceptance Scenario 3).
4. **Live resize crosses the boundary** — with the app open in a resizable
   desktop/web window, drag the window width across 600dp in both
   directions. Confirm navigation switches presentation immediately, with
   no lost tab selection and no visible flicker/oscillation exactly at the
   boundary (Acceptance Scenario 4, Edge Cases).
5. **Screen state survives the crossing (Clarification Q2)** — on a screen
   with a scrollable list (e.g. Tổng quan's recent-transactions section),
   scroll partway down; then resize the window across 600dp. Confirm the
   scroll position is unchanged after the resize. Separately, if a screen
   with a text field is open (e.g. an income amount field) and text has
   been typed but not submitted, resize across 600dp and confirm the typed
   text is still there — the screen must not visibly reset or flash
   (Acceptance Scenario 5).
6. **Content max-width on Tổng quan/Báo cáo** — at a window width of 840dp
   or wider, confirm both screens' main content stops growing past a
   fixed, centered width instead of stretching edge-to-edge; at an
   ultra-wide window, confirm it still doesn't grow further (User Story 2,
   Acceptance Scenarios 1–3). At a width below 840dp, confirm both screens
   look pixel-identical to their pre-feature layout.
7. **Tooltips on hover (desktop/web only)** — with a mouse available,
   hover over a few icon-only controls across different screens (not just
   the ones this feature directly touches — the tap-target/tooltip/focus
   work happens at the shared theme level, so it should already reach
   other screens too) and confirm a short tooltip appears (FR-008,
   Acceptance Scenario 1).
8. **Keyboard reachability (desktop/web only)** — with a keyboard
   available, press Tab repeatedly from the top of a screen and confirm
   focus visibly moves between controls in a sensible order, and that
   Enter/Space activates whichever control is focused (FR-009, Acceptance
   Scenario 2).
9. **Tap target on desktop** — on a desktop-sized window (mouse input),
   measure (or visually estimate against a 48×48dp reference) a handful of
   buttons across different screens; none should be visibly smaller than
   the same button on a phone-width layout (FR-007, Acceptance Scenario 3).

## Required Automated Regression Coverage

- `test/flutter_test_config.dart` exists and pins the default widget-test
  surface size (research.md Decision 4) — added and verified *before* any
  other test in this feature is written, since every other test's meaning
  depends on it.
- `test/unit/core/theme/app_layout_test.dart` — `windowSizeClassFor`
  boundary coverage at 599/600, 839/840, 1199/1200, 1599/1600.
- `test/widget/core/router/app_shell_nav_bar_test.dart` — extended with an
  expanded-width (rail) assertion set mirroring the existing compact-width
  ones, plus a resize scenario asserting `GlobalKey` reparenting preserves
  a descendant screen's local state (Clarification Q2).
- `test/widget/core/widgets/adaptive_body_test.dart` — below/at/above
  840dp.
- `test/widget/features/expenses/overview_screen_test.dart` and
  `report_screen_test.dart` — extended with a capped-width assertion at
  ≥840dp, alongside their existing compact-width coverage (unchanged).
- A tap-target-size sweep assertion at a desktop-sized (`linux`/`macOS`/
  `windows`-equivalent) test configuration, confirming ≥48×48dp.
- Full existing suite (386 tests as of this feature's start — SC-005)
  stays green: `flutter analyze`, `dart format --output=none
  --set-exit-if-changed lib test`, `flutter test`.
