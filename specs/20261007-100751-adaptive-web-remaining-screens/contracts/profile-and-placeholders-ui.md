# Contract: Hồ sơ and the "Not Available Yet" Placeholders on Wide Windows

**Feature**: `20261007-100751-adaptive-web-remaining-screens` | **Stories**: US5 (P5), US6 (P6) | **Date**: 2026-10-07
**Files**: `lib/features/account/presentation/account_screen.dart`,
`lib/core/widgets/not_available_placeholder_screen.dart`, `lib/core/widgets/empty_state_view.dart`

## Hồ sơ (US5)

`AccountScreen`'s `ListView` takes the gutters of `AdaptiveGutters()` (960 dp from 840 dp), the same values Bảo mật
reaches through `AdaptiveBody()`, so the two columns coincide.

| ID | Rule | Verified by |
|----|------|-------------|
| A1 | The identity header, appearance card, language row, menu card and sign-out row are one column ≤ 960 dp, centered (±8 px) beside the rail. | widget test at 1440 and 2560 |
| A2 | Hồ sơ's column and Bảo mật's column have the same left edge and width (≤ 8 px difference) at 840, 1200, 1440, 1600 and 2560; Hồ sơ → Bảo mật → Back does not shift the content. | widget test measuring both screens; browser |
| A3 | Between 600 and 839 dp both screens use the viewport width minus the 18 dp gutters (as Bảo mật today). | widget test at 700 |
| A4 | Language pop-up and sign-out keep their behavior; the language pop-up follows the shared dialog contract D1/D2/D5 of `plan-screen-ui.md`. | existing `account_screen_test.dart` + a pop-up test |
| A5 | Menu rows: ≥ 48 dp high, hover tint and focus ring, tooltips where icon-only; Tab order follows the visual order. | widget test; browser |
| A6 | Wheel scrolling works over the whole window; in a 1440 × 500 window every row is reachable. | browser |
| A7 | Compact: unchanged; `account_screen_test.dart` passes unmodified. | existing tests |
| A8 | The app bar keeps its title strip full-width, as the other tabs. | widget test |

## Placeholders (US6)

Applies to `NotAvailablePlaceholderScreen`, used by Thông báo (from the Tổng quan bell and from Hồ sơ) and Trợ giúp.

`body: AdaptiveBody(child: EmptyStateView(...))` — the placeholder has no scroll view of its own to span the window
(`EmptyStateView` scrolls internally only when it overflows), so the wrapper is correct here and needs no gutters.

| ID | Rule | Verified by |
|----|------|-------------|
| N1 | At ≥ 840 dp the icon and message are centered inside the ≤ 960 dp bounded area; nothing is clipped; at 320 dp the message wraps without overflow. | widget test at 320, 412, 1440, 2560 |
| N2 | The back button (and Escape/browser Back) returns to the previous screen: Tổng quan for the bell, Hồ sơ for the menu entries. | existing router tests + browser Back |
| N3 | The back button has a tooltip and a ≥ 48 dp target (framework `BackButton` default; verified). | widget test |
| N4 | In a 2560 × 500 or 320 × 400 window the message scrolls instead of overflowing. | widget test |
| N5 | Compact: unchanged; `not_available_placeholder_screen_test.dart` and `empty_state_view_test.dart` pass unmodified. | existing tests |

The two placeholders that are tab destinations pushed in place (`/overview/notifications`, `/account/placeholder/:feature`)
share the widget, so one change covers all three entry points.
