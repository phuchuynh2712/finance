# Feature Specification: Adaptive Layout Foundation

**Feature Branch**: `20260925-024749-adaptive-layout-foundation`
<!-- Logical feature identifier only (matches this spec directory's name), per
     this repo's established convention — e.g. specs/20260924-181441-report-
     monthly-summary/plan.md uses the same pattern. The actual git branch for
     this work stays the session-designated `claude/sweet-fermi-yd1qj8`; no
     separate git branch is created for this feature. -->

**Created**: 2026-09-25

**Status**: Draft

**Input**: User description: "Nghiên cứu UI hiện tại render giống hệt nhau ở
mọi kích thước cửa sổ (mobile/web/desktop) dù giao diện nguồn được thiết kế
riêng cho từng loại màn hình. Chốt tại constitution v1.5.0: layout phải theo
window size (Material 3 breakpoints), không theo platform; Web là nền tảng
được hỗ trợ đầy đủ, Desktop để ngỏ. Feature này lấy phần nền tảng đầu tiên
trong lộ trình đã thống nhất: token/breakpoint dùng chung, shell điều hướng
tự đổi giữa bottom bar và rail, giới hạn bề rộng nội dung ở 2 màn hình
Tổng quan/Báo cáo, và chuẩn hoá tap-target/hover/tooltip/keyboard ở tầng
theme dùng chung — không bao gồm redesign từng màn hình còn lại hay sửa lỗi
nền tảng Web (xem 'Out of Scope & Follow-Up Work' bên dưới, được ghi chi
tiết theo yêu cầu để không bị quên khi bắt đầu spec kế tiếp)."

## Clarifications

### Session 2026-09-25

- Q: Ở dải rail (cửa sổ ≥600dp), mỗi điểm đến hiển thị icon+nhãn chữ, hay
  chỉ icon? → A: Icon + nhãn chữ luôn hiển thị (giữ giống bottom bar hiện
  tại), ở mọi kích thước rail — không có mốc breakpoint thứ ba trong
  feature này.
- Q: Khi cửa sổ đổi từ compact sang expanded (hoặc ngược lại), trạng thái
  cục bộ của màn hình đang xem (vị trí cuộn, nội dung đang gõ dở chưa
  submit...) có bắt buộc giữ nguyên không, hay chỉ bảo đảm trạng thái điều
  hướng? → A: Toàn bộ trạng thái cục bộ của màn hình đang xem đều phải giữ
  nguyên — màn hình hiện tại không được remount, chỉ phần khung điều hướng
  bao quanh nó thay đổi.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Navigation adapts to window size (Priority: P1)

As someone using the app on a phone, a tablet, a desktop, or a web browser,
I want the main navigation to fit the space I actually have, so that
switching between Tổng quan, Kiểm soát, Thu chi, Báo cáo, and Hồ sơ stays
comfortable whether I'm on a narrow phone screen or a wide desktop window,
instead of always seeing the same cramped phone-style bottom bar stretched
across a wide screen.

**Why this priority**: This is the single most visible instance of the
"web and mobile look identical" problem, and it's structural — every other
screen lives inside this navigation shell, so getting this right first
gives the highest visible return and de-risks everything that follows.

**Independent Test**: Open the app at a narrow (phone-sized) width and
confirm navigation still looks and behaves exactly as it does today (bottom
bar, 5 destinations); then open or resize the same app to a wide width
(tablet landscape, desktop, or a wide browser window) and confirm
navigation presents as a side rail with the same 5 destinations, the same
selected tab, and the same unsaved-changes prompt when leaving Kiểm soát —
this is fully verifiable on its own, without any other story in this spec.

**Acceptance Scenarios**:

1. **Given** the app window is narrower than 600 logical pixels, **When**
   the app is shown, **Then** navigation appears as a bottom bar with all 5
   destinations, exactly as today.
2. **Given** the app window is 600 logical pixels wide or wider, **When**
   the app is shown, **Then** navigation appears as a side rail with the
   same 5 destinations, each showing its icon and text label together
   (matching the bottom bar's existing presentation, not icon-only), and
   whichever tab was already selected stays selected.
3. **Given** the app is open at a narrow width on the Kiểm soát tab with
   unsaved formula edits, **When** the window is resized past 600 logical
   pixels and the user selects a different rail destination, **Then** the
   same save/discard/cancel confirmation prompt appears as it does today
   from the bottom bar, with identical behavior for each choice.
4. **Given** the app window is resized live (a desktop or web browser
   window being dragged wider or narrower, or an Android split-screen/
   foldable resize), **When** the width crosses the 600-pixel threshold in
   either direction, **Then** navigation switches presentation immediately
   without losing the current tab or any in-progress screen state.
5. **Given** a user has scrolled partway down a list, or has typed text
   into a field without submitting it, on any screen, **When** the window
   is resized across the 600-pixel threshold, **Then** the scroll position
   and the unsubmitted text remain exactly as they were before the resize
   — the screen is not rebuilt from scratch, only the navigation chrome
   around it changes.

---

### User Story 2 - Content doesn't stretch edge-to-edge on wide screens (Priority: P2)

As someone viewing Tổng quan (Overview) or Báo cáo (Report) on a wide
window, I want the balance cards, totals, and lists to stay a comfortable
reading width and stay centered, instead of stretching all the way across
the window, so the numbers stay as easy to scan and compare as they are on
my phone today.

**Why this priority**: Directly answers the original complaint on the two
screens people check most often (balance and monthly report). Independent
of User Story 1 — it's about content layout, not navigation — so it can be
built, demoed, and verified separately.

**Independent Test**: Open Tổng quan (or Báo cáo) at a wide window width
and confirm the content area stops at a fixed, centered maximum width
instead of spanning the full window; at a narrow (phone) width, confirm the
layout is pixel-identical to today, with no regression.

**Acceptance Scenarios**:

1. **Given** the app window is narrower than 840 logical pixels, **When**
   Tổng quan or Báo cáo is shown, **Then** the layout is unchanged from
   today (content fills the available width, as now).
2. **Given** the app window is 840 logical pixels wide or wider, **When**
   Tổng quan or Báo cáo is shown, **Then** the main content area stops
   growing past a fixed maximum width and is centered in the remaining
   space.
3. **Given** the app window is very wide (e.g. an ultra-wide desktop
   monitor), **When** Tổng quan or Báo cáo is shown, **Then** the content
   still respects the same maximum width rather than continuing to grow.

---

### User Story 3 - Every control works well with touch, mouse, and keyboard (Priority: P3)

As someone using the app with a mouse and keyboard (desktop or web) as well
as someone using touch (phone or tablet), I want every button and icon to
be easy to click or tap, to show what it does before I commit to clicking
it, and to be operable from the keyboard, so the app feels native to
whichever input method I'm using instead of feeling like a shrunk-down
phone app pasted onto a desktop screen.

**Why this priority**: Lower visual impact than US1/US2, but it is
implemented once at the shared theme/component level, so it benefits every
screen in the app immediately — independent of both other stories — and it
closes a concrete gap the research behind this feature found: desktop
platforms default to a smaller effective tap target than the app's own
48×48dp minimum already requires everywhere else.

**Independent Test**: On a desktop/web session, hover over icon-only
buttons across a few different screens and confirm a tooltip appears; tab
through a screen's primary controls with the keyboard and confirm a
visible focus indicator moves in a sensible order and Enter/Space
activates the focused control; measure a sample of buttons' clickable area
at a desktop window size and confirm it is at least 48×48 logical pixels.

**Acceptance Scenarios**:

1. **Given** the app is running with a mouse available, **When** the
   pointer hovers over an icon-only button, **Then** a short text label
   (tooltip) describing its action appears.
2. **Given** the app is running with a keyboard available, **When** the
   user presses Tab repeatedly from the start of a screen, **Then** focus
   moves between interactive controls in a logical order with a visible
   focus indicator, and Enter or Space activates whichever control is
   focused.
3. **Given** any window size, including a desktop-sized window, **When** a
   user measures any interactive control's clickable area, **Then** it is
   at least 48×48 logical pixels, matching the app's existing mobile
   behavior.

---

### Edge Cases

- What happens when the window is resized to exactly a breakpoint boundary
  (600px, 840px)? Layout MUST pick one side consistently, with no
  flicker or oscillation exactly at the boundary.
- How does the system handle a foldable or multi-window Android device
  where the window briefly reports an unusual or transitional size during
  a fold/unfold animation? It MUST NOT crash or show a broken intermediate
  layout; briefly showing either valid layout mid-transition is acceptable.
- What happens on a device with both touch and a connected mouse/keyboard
  at the same time (e.g. a Chromebook, an iPad with a trackpad, a Windows
  tablet)? Both input styles MUST work simultaneously — the presence of
  touch MUST NOT suppress the tooltip/keyboard support from User Story 3.
- How does a screen-reader/assistive-technology user experience the rail
  versus the bottom bar? Semantics/labels MUST stay equivalent between the
  two navigation presentations — existing screen-reader support MUST NOT
  regress.
- What happens if the window is resized while a Kiểm soát edit is pending?
  The layout switch alone MUST NOT discard or reset the pending edit —
  only an explicit navigation action (per User Story 1's existing prompt)
  may do that.
- What happens to a screen's own local state (scroll position, text typed
  into a field but not yet submitted) when the window crosses a breakpoint
  mid-use? It MUST be preserved exactly as if the window had not been
  resized at all — the screen is not remounted, only the navigation chrome
  around it changes.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST present its primary navigation as a bottom bar
  when the window is narrower than 600 logical pixels, and as a side rail
  with the same destinations when the window is 600 logical pixels wide or
  wider. The rail MUST show each destination's icon together with its text
  label at every rail width — never icon-only — matching the bottom bar's
  existing presentation.
- **FR-002**: The app MUST base this and every other layout decision in
  this feature purely on the current window size, never on which device,
  operating system, or platform the app happens to be running on.
- **FR-003**: Switching between the two navigation presentations MUST
  preserve the currently selected tab and MUST NOT reset any in-progress
  screen state — including scroll position, text typed into a field but
  not yet submitted, and any other local state of the screen currently
  being viewed. The currently viewed screen MUST NOT be torn down and
  rebuilt purely because the window crossed a breakpoint; only the
  surrounding navigation chrome changes.
- **FR-004**: The existing confirmation prompt for unsaved Kiểm soát
  formula edits MUST behave identically regardless of which navigation
  presentation triggered the tab switch.
- **FR-005**: On the Tổng quan and Báo cáo screens, the main content area
  MUST stop growing in width once the window reaches 840 logical pixels,
  and MUST remain centered within the available space beyond that point.
- **FR-006**: Below 840 logical pixels, the Tổng quan and Báo cáo screens'
  layout MUST remain visually unchanged from current behavior.
- **FR-007**: Every interactive control in the app MUST have a
  clickable/tappable area of at least 48×48 logical pixels, regardless of
  window size or input method — including on platforms where the
  underlying UI toolkit would otherwise default to a smaller size — except
  a control that already carries its own explicit, documented exception
  (e.g. a code comment recording a deliberate design decision, as already
  exists for one control predating this feature). This feature MUST NOT
  introduce any new undocumented sub-48×48dp control, and MUST bring any
  *undocumented* pre-existing one up to 48×48dp.
- **FR-008**: Every icon-only control MUST expose a short descriptive
  tooltip, visible when a pointer device is present.
- **FR-009**: Every primary interactive control MUST be reachable via
  keyboard navigation, in a logical order, with a visible focus indicator,
  and MUST be activatable via a standard keyboard activation key.
- **FR-010**: All breakpoint widths and the content maximum-width value
  used by this feature MUST be defined as a single, shared, reusable set
  of values rather than repeated or redefined per screen.
- **FR-011**: This feature's changes MUST NOT reduce existing
  screen-reader/accessibility label coverage, remove existing dark-mode
  support, or alter any financial figure's formatting.
- **FR-012**: The full existing automated test suite MUST continue to pass
  after this feature, and the default/assumed testing window size MUST be
  explicit and documented rather than left to a tool default.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: At any window width from 320 to 2560 logical pixels, all 5
  navigation destinations remain visible and reachable in a single
  interaction, with no horizontal scrolling and no hidden overflow menu.
- **SC-002**: On the Tổng quan and Báo cáo screens, at a window width of
  840 logical pixels or greater, the main content column measures no more
  than 960 logical pixels wide and is horizontally centered.
- **SC-003**: 100% of a full sweep of interactive controls (buttons, icon
  buttons, navigation destinations) across every screen — excluding any
  control with its own documented sizing exception (FR-007) — measure at
  least 48×48 logical pixels in clickable area, verified at both a compact
  and an expanded window size.
- **SC-004**: A user relying solely on a keyboard can reach and activate
  each of the 5 main tabs (the navigation action itself) and at least one
  primary in-screen action, without using a pointer.
- **SC-005**: The existing automated test suite (386 tests as of this
  feature's start) passes in full after this feature, with no test's
  outcome changed as an unintended side effect of the layout change.

## Assumptions

- Material Design's window size class thresholds (600 / 840 / 1200 / 1600
  logical pixels), already adopted in the project constitution (v1.5.0),
  are the reference breakpoints for this feature; no separate breakpoint
  scheme is introduced.
- A navigation drawer is explicitly not used at any size, per the
  constitution — the side rail is the only wide-window navigation
  presentation in scope.
- A content maximum width of 960 logical pixels for the Tổng quan/Báo cáo
  dashboard-style screens is used as this feature's starting default;
  later screens (e.g. list-detail views, forms) may use a different
  maximum appropriate to their own content, decided when each is tackled
  individually — see "Out of Scope & Follow-Up Work" below.
- "Window size" means the available space the app itself is drawn into
  (the browser tab, the OS window, the device screen), not the physical
  device's full screen size — e.g. a phone in split-screen counts by its
  actual allotted width, not the full device width.
- This feature changes shared infrastructure (theme tokens, the app
  shell, and two proof-of-concept screens) but deliberately does not
  redesign the remaining screens; the complete, itemized list of what is
  intentionally deferred — and why — is recorded below, in detail, on the
  user's explicit request, so it is not lost once this feature ships.
- No new user-facing setting is introduced (e.g. no manual "desktop mode"
  toggle) — the adaptive behavior is automatic and driven only by window
  size.
- SC-001's 320–2560 logical-pixel range is verified via boundary-value
  testing at each breakpoint threshold plus representative renders on
  either side (not an exhaustive pixel-by-pixel sweep) — sufficient
  because the underlying width-to-layout mapping is a simple, monotonic
  threshold classifier: if it is correct at every boundary and renders
  correctly at one representative point per side, it is correct across
  the whole range between those boundaries.

## Implementation Notes

*Recorded during `/speckit-implement`'s Foundational phase — real, pre-
existing issues that `test/flutter_test_config.dart` (this feature's
pinned compact test default) exposed by finally testing at a realistic
phone width, instead of `flutter_test`'s own unpinned 800×600 default
(which is tablet-scale, not phone-scale). None of these were caused by
this feature; all were latent before it. Fixed here rather than deferred,
since a red test suite cannot be left behind at a phase checkpoint.*

- **Four pre-existing `RenderFlex` overflow bugs**, all only visible at a
  realistic compact width, fixed by letting text wrap instead of
  overflowing (never by truncating — no `TextOverflow.ellipsis` was
  introduced anywhere, keeping Principle III's no-truncation rule intact):
  `lib/core/widgets/empty_state_view.dart` (wrapped its message Column in
  `SingleChildScrollView`), `lib/features/expense_control/presentation/
  expense_control_screen.dart`'s header title (wrapped in `Expanded`),
  `lib/features/expenses/presentation/expense_screen.dart`'s type-toggle
  button label and `lib/features/expenses/presentation/income_screen.dart`'s
  add-source button label (both wrapped in `Flexible`, preserving their
  centered-pill look when content fits, as it normally does).
- **FR-017/SC-006 (an earlier feature's requirement, predating this one)
  relaxed by product decision**: bottom-nav destination labels were
  required to always render on a single line. Empirical testing (probing
  the real production widget/theme/strings directly, not guessing) found
  "Tổng quan" — the longest label — never fits on one line at *any*
  realistic phone width; even 600 logical pixels (120px per destination,
  wider than any real phone) still wrapped it. The only single-line-only
  fix found required shrinking every label to 8sp, well below Material 3's
  12sp default and judged too small to ship without a design pass. Given
  the choice between illegibly small text, renaming a tab, or accepting a
  2-line wrap, the decision (asked of and made by the user) was to accept
  the wrap: `NavigationBar`'s own default layout already accommodates a
  2-line label within its fixed height without clipping or overflowing
  (confirmed empirically) — no widget change was needed, only relaxing
  `test/widget/core/router/app_shell_nav_bar_test.dart`'s assertion from
  "single line" to "renders fully, no overflow, no truncation."

## Out of Scope & Follow-Up Work

*This section is deliberately detailed and engineering-specific — unlike
the rest of this spec — because it exists specifically so that whoever
picks up work after this feature ships (including a future session with no
memory of this conversation) can act on it without re-deriving it from
scratch. Each item below is either (A) a concrete defect already confirmed
during this feature's research, not newly introduced by it, or (B) a
screen intentionally left out of this feature's redesign. Nothing here is
scheduled or committed to a specific follow-up spec yet — this is the
backlog to draw the next spec(s) from.*

### A. Web platform enablement (not covered by this feature — separate, data/security-sensitive)

These are **pre-existing defects**, confirmed by reading the current code,
not caused by this feature. This feature makes screens lay out correctly
at any window size, including in a browser — but most of them will still
fail to load real data on Web until this group is fixed separately, because
the problem is in the data/auth layer, not the layout. Deliberately kept
out of this feature (per the scope decision made with the user) because it
is a different risk class — data integrity and auth security — that
deserves its own focused review, not one bundled into a UI-layout PR.

**This is a live, currently-unresolved constitution conflict, not merely a
"nice to have" backlog item.** The constitution's Multi-Platform Support
section states unconditionally that a Web data flow failing "is a
Principle I defect, not an acceptable platform gap" — that defect exists
right now and remains open after this feature ships. Deferring it here was
a deliberate, informed scope decision (a different risk class, reviewed
separately), not a reason to let it go unscheduled. The follow-up below is
not optional busywork — it is required to bring the codebase back into
constitution compliance on Web, and should be started promptly rather than
left indefinitely "suggested."

1. **Local database does not open on Web at all.**
   `lib/core/database/app_database.dart:12` calls
   `driftDatabase(name: 'finance')` with no `web` parameter. The
   `drift_flutter` package requires that parameter on Web and throws
   `ArgumentError` there without it — meaning **every screen that reads
   the database fails on Web today**, not just ones this feature touches.
   Fix: supply `DriftWebOptions` (a `sqlite3.wasm` and a `drift_worker.js`
   placed under `web/`, served with `Content-Type: application/wasm`);
   optionally add COOP/COEP response headers to unlock the faster OPFS
   storage backend instead of the IndexedDB fallback.

2. **Password-reset redirect is hardcoded to a mobile deep link.**
   `lib/core/auth/auth_repository.dart:101` sets
   `redirectTo: 'com.finance.finance://reset-callback'` unconditionally.
   That URI scheme does not open in a web browser. Web needs an `https://`
   redirect URL, chosen per platform at runtime, and that URL added to
   Supabase's allowed redirect list.

3. **No app-level lock exists on Web at all — a constitution gap, not just
   a missing nicety.** `lib/core/auth/biometric_login_repository.dart:22`
   and `:33` both return `false` under `kIsWeb`, and no PIN-entry fallback
   is implemented anywhere in the app today. The amended constitution
   (Security section) requires a PIN path when biometric is unavailable;
   right now Web silently has no app-level lock, not merely a degraded
   one.
4. **Secure storage on Web is explicitly experimental.** `lib/core/
   storage/secure_local_storage.dart` wraps `flutter_secure_storage` for
   the Supabase session; that package's own README (checked at the
   version pinned in `pubspec.lock`) states its Web implementation is
   "experimental," backed by WebCrypto + `localStorage`, and calls out
   that HSTS must be correctly configured or the stored session is
   vulnerable to a JS-injection hijack. Needs an explicit accept-the-risk
   decision or a hardening pass before Web ships broadly.
5. **App identity still shows Flutter's scaffolding defaults.**
   `web/manifest.json` (name/short_name "finance", Flutter's default blue
   `#0175C2` theme color, `"orientation": "portrait-primary"` — nonsensical
   for a resizable desktop browser window), `web/index.html` (`<title>
   finance</title>`, description "A new Flutter project."), and
   `lib/main.dart:60`'s `MaterialApp.title: 'Finance'` (not "Kiểm Soát")
   all still read as an unconfigured template, not the shipped product.
6. **URL strategy is undecided.** The app currently uses Flutter's default
   hash-based web routing (`/#/overview`) unless `usePathUrlStrategy()` is
   added — worth an explicit decision, not an accidental default.
7. Several screens open sub-screens via `Navigator.of(context).push
   (MaterialPageRoute(...))` instead of a router route — see
   `lib/features/expenses/presentation/spending_screen.dart:52,67,79`,
   `lib/features/expenses/presentation/overview_screen.dart:126,389`, and
   `lib/features/account/presentation/account_screen.dart:195`. On Web
   these never get their own URL (no back-button/bookmark support), and
   they will also need to become real routes for the list-detail layouts
   planned in section B below to work coherently. Belongs with whichever
   spec restructures navigation for Web/list-detail, likely this group or
   section B's Lịch sử/Hồ sơ items — not decided yet.

**Suggested next spec**: `web-platform-enablement` (or similar) — treat as
partially a Security-section change (items 2–4), not purely a bugfix.

### B. Per-screen adaptive redesign backlog (every screen this feature does not touch)

This feature only reworks the app shell and the Tổng quan/Báo cáo content
width. Every other screen keeps today's single-column mobile layout at
every window size until it gets its own follow-up work. Listed with a
starting-point guess for its eventual adaptive treatment — none of these
are committed designs, just where the research above left off:

- **Kiểm soát** (`lib/features/expense_control/presentation/
  expense_control_screen.dart`) — currently a single-column `ListView` of
  group cards. Likely candidate: a 2–3 column card grid at ≥600dp.
- **Thu chi / nhập giao dịch** (`lib/features/expenses/presentation/
  expense_screen.dart`, `income_screen.dart`) — currently a full-screen
  on-screen keypad flow. Likely candidate: a side panel or dialog on wide
  windows instead of a full-screen takeover. Also note: a comment at
  `expense_screen.dart:381` ("has no effect (research.md's keypad-is-static
  note)") suggests physical-keyboard number entry may not currently work
  here at all — worth confirming and fixing as part of this same
  follow-up, since desktop/web users will expect to type amounts.
- **Lịch sử giao dịch** (`lib/features/expenses/presentation/
  transaction_history_screen.dart`) — currently pushed full-screen via
  `MaterialPageRoute`. Likely candidate: a list-detail split (list on the
  left, selected transaction's detail on the right) at ≥840dp, which also
  needs the routing fix noted in section A.7.
- **Hồ sơ** (`lib/features/account/presentation/account_screen.dart`) and
  its pushed sub-screens — likely candidate: list-detail (settings list +
  detail pane), same pattern as Lịch sử.
- **Auth screens** — Đăng nhập (`sign_in_screen.dart`), Đăng ký
  (`sign_up_screen.dart`), Quên mật khẩu (`forgot_password_screen.dart`),
  Đặt lại mật khẩu (`reset_password_screen.dart`) — currently a
  stretch-to-fill column inside `SingleChildScrollView`. Likely candidate:
  a centered card with a bounded width (~440–480dp) on wide windows,
  reusing this feature's shared max-width token from User Story 2 if it
  turns out to fit, or a narrower dedicated value if not.

**Suggested next spec(s)**: one per screen or logical group (e.g.
"kiem-soat-adaptive-grid", "history-profile-list-detail",
"expense-entry-adaptive-panel", "auth-screens-centered-card") — small
enough to stay independently reviewable, matching how every prior feature
in this repository has shipped.

### C. Explicitly not planned yet

- **Native Desktop** (Windows/macOS/Linux) stays fully deferred per the
  constitution's Multi-Platform Support section — no platform folders
  exist yet (`flutter create --platforms=...` has not been run), and
  nothing above assumes or requires it. Not even a follow-up spec is
  implied here unless a future request explicitly asks for it.
