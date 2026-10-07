# Contract: Final Sweep (Story 7)

**Feature**: `20261007-100751-adaptive-web-remaining-screens` | **Story**: US7 (P7) | **Date**: 2026-10-07

The sweep is the last pull request. It adds no feature; it proves every screen, finished or not, behaves across the
width range, and it fixes every defect it finds in this feature (FR-018, clarified 2026-10-07: "fix every defect, whatever
its size"). The inventory is `data-model.md` §3.

## Matrix

| Axis | Values |
|------|--------|
| Widths (dp) | 320, 412, 600, 840, 1200, 1600, 2560 |
| Heights (dp) | 915 (phone), 900 (laptop), 650 (laptop browser view), 640 (Chi tiêu floor), 500 (short); 390 (a phone held sideways) for Chi tiêu |
| Appearance | light, dark |
| Text scale | 1.0 and 1.3 (a spot check on the dense screens: Kế hoạch, Chi tiêu, Hồ sơ) |
| Input | mouse + keyboard (browser), touch (emulator, simulator for compact only) |

## Layer 1: automated (committed)

`test/widget/core/adaptive_sweep_{auth,overview_report,history,spending,account,static}_test.dart` (helper `test/support/adaptive_sweep.dart`) mount every inventory screen with the provider overrides its own widget
test already uses (copied into `test/support/`, existing tests untouched), in three case groups: every width above in light and dark at 800 dp high; a 500 dp-high window at 412 and 1440 dp wide; and 130 % text size at 320, 412 and 1440 dp wide. Each case asserts `tester.takeException() == null` (no
`RenderFlex overflowed`, no layout assertion), that no `Scrollable` ancestor of an interactive element is stuck at a
zero-size viewport, and for the screens that bound their content that the column width ≤ its token. Fixtures are copied
from the existing screen tests into `test/support/` (the originals stay as they are); no new fake backend.

## Layer 2: browser pass (recorded as text)

Throwaway Playwright scripts in the session scratchpad, run against `flutter build web` served from `build/web`:

| Check | Pass condition |
|-------|----------------|
| Overflow / clip / overlap | no console error `RenderFlex overflowed`; no semantics node clipped to zero height that has an action |
| Dead zones | wheel over x = 150 and x = window − 150 scrolls the same as over the column on every scrolling screen |
| Centering | column left/right edges within 8 px of the area beside the rail (SC-004) |
| Hồ sơ ↔ Bảo mật | same column x and width (SC-007) |
| Keyboard | Tab reaches every control in visual order; focus visible; Enter/Space activate; Escape closes pop-ups |
| Hover | hover tint on rows/buttons; tooltips on icon-only controls |
| Resize | resize 1440 → 412 → 1440 mid-task on Chi tiêu, Thu nhập, Kế hoạch keeps values (SC-006) |
| Zoom | 200 % and 400 % behave like a 720 × 450 and 360 × 225 window: scroll, nothing hidden |

The result is a table in `verification/README.md` (screen × width × appearance → pass/fix reference). No screenshots are
committed.

## Layer 3: compact regression on real platforms

Android emulator (Pixel_10) and the iOS simulator (iPhone 17): the six changed screens at compact are checked for "no
difference" against the pre-change build (side-by-side `uiautomator`/AXe tree comparison or on-device inspection,
recorded as text). Required by SC-005.

## Known defect to fix in this story (found while planning)

| Defect | Evidence | Fix |
|--------|----------|-----|
| Mouse-wheel / trackpad do nothing over the side margins of Tổng quan (and, to be confirmed in the sweep, Báo cáo and Lịch sử giao dịch) because `AdaptiveBody` wraps the `ListView`, so the scroll view is only column-wide | 1440 × 500: wheel at x = 250 → content stays at y = 80; wheel at x = 720 → y = 62 | give those screens' scroll views the full viewport using `AdaptiveGutters` (research Decision 1); keep their look at every width. Three existing tests encode the old structure and are re-pointed in the same pull request with the same intent (content ≤ 960 and centered): `report_screen_test.dart` and `overview_screen_test.dart` measure `find.byType(ListView)` as 960 wide at x = 120 (it is now viewport-wide with 120 dp of padding), and `transaction_history_screen_test.dart` looks for a `ConstrainedBox` under `AdaptiveBody`; every other assertion in them stays |

Any further defect: record it (screen, size, symptom), fix it in the shared code if it comes from shared code
(constitution: root-cause rule), add a regression test, re-run the matrix row.

## Done when

All inventory rows pass layers 1–3 with no open defect; the log lists every defect found with its fix; the full suite,
`flutter analyze` and `dart format --set-exit-if-changed` pass.
