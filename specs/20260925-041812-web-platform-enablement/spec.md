# Feature Specification: Web Platform Enablement

**Feature Branch**: `20260925-041812-web-platform-enablement`
<!-- Logical feature identifier only (matches this spec directory's name), per
     this repo's established convention — e.g. specs/20260925-024749-adaptive-
     layout-foundation/spec.md uses the same pattern. The actual git branch
     for this work stays the session-designated `claude/sweet-fermi-yd1qj8`;
     no separate git branch is created for this feature. -->

**Created**: 2026-09-25

**Status**: Draft

**Input**: User description: "Web platform enablement: fix the pre-existing,
previously-documented defects that keep the Web target from being 'fully
supported' per constitution v1.5.0's Multi-Platform Support section — this is
the §A follow-up backlog recorded in adaptive-layout-foundation's spec.md.
Three prioritized user stories: P1 (CRITICAL, blocking) — the local Drift
database never opens on Web at all (`driftDatabase(name: 'finance')` is
missing the `web:` parameter `drift_flutter` requires there), so no screen
that reads data works on Web today; needs `DriftWebOptions` with
`sqlite3.wasm` + `drift_worker.js`. P2 — the password-reset redirect is
hardcoded to a mobile deep link (`com.finance.finance://reset-callback`),
which cannot open in a browser; Web needs a real `https://` redirect chosen
at runtime per platform (noting the matching Supabase Dashboard allowed-
redirect-URL configuration is the user's own action item, outside this
codebase). P3 — Web still presents as unconfigured Flutter scaffolding
(`web/manifest.json`, `web/index.html`, `MaterialApp.title`) instead of the
shipped 'Kiểm Soát' product, and should use path-based URL routing instead of
the default hash strategy. Explicitly out of scope, each deferred to its own
future spec: an app-level PIN-entry lock for platforms without biometric
(Web has none today), a risk-acceptance/hardening decision on
`flutter_secure_storage`'s experimental Web backend, and converting
`Navigator.push` call sites to real `go_router` routes (better done together
with the per-screen list-detail redesigns that will actually need them).
These three deferred items are recorded in this spec's own Out-of-Scope
section in the same detailed, evidence-rich way the previous feature did."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Signed-in data actually loads on Web (Priority: P1)

As someone who opens the app in a web browser and signs in, I want to see my
real expense-control groups, transactions, and balances — the same data I'd
see on my phone — instead of the app failing to load any data, so that Web
is an actually usable way to check and manage my finances, not just a UI
shell that never shows real content.

**Why this priority**: This is the CRITICAL, blocking defect identified
during the previous feature's analysis — the local database never opens on
Web at all today, so literally no screen that reads or writes data works
there. Nothing else in this feature matters if this isn't fixed first, and
every other Web-facing improvement is worthless without it.

**Independent Test**: Sign in on a web build, land on Tổng quan, and confirm
real balances and Kiểm soát groups render (matching what the same account
shows on mobile) instead of an error or a permanently empty/loading state;
record a transaction, reload the page, and confirm the change is still
there.

**Acceptance Scenarios**:

1. **Given** a signed-in user opens the web app, **When** any screen that
   reads expense-control items or transactions is shown, **Then** the real
   data loads and displays, matching the same account's data on mobile.
2. **Given** a signed-in user on Web records a new transaction or edits a
   Kiểm soát formula, **When** the action completes, **Then** the change is
   persisted locally and is still present after a full page reload.
3. **Given** a user opens the web app for the first time in a given browser,
   **When** the app initializes its local database, **Then** no unhandled
   error occurs and the app reaches its normal signed-in home screen.
4. **Given** a browser that does not support the fastest available storage
   backend (e.g. missing the cross-origin isolation headers OPFS requires),
   **When** the app initializes its local database, **Then** it falls back
   to a working storage backend instead of failing to open at all.

---

### User Story 2 - Password reset works from a browser (Priority: P2)

As someone who requests a password reset while using the web app, I want
the reset link to open a working page in my browser, so I can actually get
back into my account instead of the link failing silently because it points
to a mobile-only address.

**Why this priority**: A real account-recovery blocker for Web users, but it
only affects the subset of users who forget their password — lower reach
and frequency than User Story 1's total Web data outage, and independent of
it (this is an auth-redirect fix, not a data-loading fix).

**Independent Test**: Trigger "forgot password" from a web-app session and
inspect the generated redirect URL; confirm it targets a valid `https://`
address rather than the mobile deep-link scheme, and that requesting the
same reset from the mobile app is unaffected.

**Acceptance Scenarios**:

1. **Given** a user requests a password reset while using the web app,
   **When** the reset email is generated, **Then** its link targets an
   `https://` URL that opens a working page in a browser, not a
   mobile-only deep-link scheme.
2. **Given** a user requests a password reset from the mobile app, **When**
   the reset email is generated, **Then** its link still targets the
   existing mobile deep link, unchanged from today's behavior.
3. **Given** the reset link opens on Web, **When** the user submits a new
   password, **Then** the existing reset-completion behavior (signing the
   account out of every session globally) behaves identically to mobile.

---

### User Story 3 - Web presents as the real "Kiểm Soát" product (Priority: P3)

As someone opening the app in a browser — via a bookmark, a shared link, or
a browser tab/task switcher — I want to see the app's real name, icon, and
color identity, and to be able to load or share a specific screen with a
normal-looking URL, so that the web app feels like a finished product
rather than an unconfigured template, and links to it behave like links to
a real website.

**Why this priority**: Lowest functional impact (identity and URL shape,
not data correctness) but cheap to fix and highly visible in browser
chrome, bookmarks, and the tab/task switcher every single time the app is
used on Web — and independent of both other stories.

**Independent Test**: Open the web build, check the browser tab title and
favicon (and the installed-PWA name/icon, if installed), and confirm they
show "Kiểm Soát" branding rather than "finance"/Flutter defaults; navigate
to a specific screen and confirm the address bar shows a clean path-based
URL rather than a `#`-prefixed hash route; load that path-based URL
directly (as a fresh page load, not in-app navigation) and confirm it
still opens the correct screen.

**Acceptance Scenarios**:

1. **Given** the web app is loaded in a browser, **When** the browser tab
   and any installed-PWA prompt are inspected, **Then** the title,
   description, and theme color reflect "Kiểm Soát" branding, not Flutter's
   scaffolding defaults.
2. **Given** the web app is navigated to a specific screen, **When** the
   address bar is inspected, **Then** the URL is a normal path (e.g.
   `/overview`) rather than a hash fragment (e.g. `/#/overview`).
3. **Given** a path-based URL for an in-app screen, **When** that URL is
   loaded directly (a fresh browser load, not reached via in-app
   navigation), **Then** the correct screen still opens, rather than a 404
   or a blank page.
4. **Given** a resizable desktop browser window, **When** the window is
   resized to any aspect ratio, **Then** the app is not locked to a
   portrait-only orientation.

---

### Edge Cases

- What happens to any local data a Web session may have stored before this
  fix ships? Nothing — since the database could never successfully open on
  Web before this feature, no Web session could ever have written real
  local data; there is nothing to migrate.
- What happens if a password reset is requested from the mobile app but the
  emailed link is opened on a desktop browser later? It still opens the
  mobile deep link, unchanged — the redirect target is chosen once, at
  request time, based on the platform that made the request, not the
  platform that later opens the email. This is existing, unchanged
  behavior (User Story 2, Acceptance Scenario 2), not a defect.
- What happens to a browser that lacks WASM support entirely (very old
  browsers)? Out of scope to specifically support — the app's minimum
  supported browser baseline is whatever `drift_flutter`/Flutter Web
  itself requires; no new lower bound is introduced by this feature.
- What happens to anyone who has bookmarked or shared one of today's
  hash-based URLs (e.g. `/#/overview`) once path-based routing ships? That
  bookmark stops resolving to the same screen. Accepted as a one-time
  transition cost: User Story 1 being broken until this feature ships means
  Web has had negligible real usage to date, so there are effectively no
  live hash-based bookmarks to preserve.
- What happens when the app is deployed to Web hosting that does not
  rewrite unknown paths back to the app shell (a plain static file host
  with no SPA fallback rule)? Directly loading a deep path-based link
  (Acceptance Scenario 3 of User Story 3) would 404 there. This feature
  changes the app to require that hosting capability; see Assumptions and
  "Out of Scope & Follow-Up Work" for why the exact hosting configuration
  itself is outside this codebase.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST successfully open its local database on Web, so
  that every screen depending on locally-stored data functions on Web the
  same as it does on mobile.
- **FR-002**: Every existing local-database read and write operation (Kiểm
  soát items, transactions, sync outbox) MUST work identically on Web and
  on mobile, with no Web-specific behavior gap.
- **FR-003**: The Web database configuration MUST fall back to a working
  storage backend when the browser does not support the fastest available
  option, without crashing or losing functionality.
- **FR-004**: Password-reset requests initiated from the Web app MUST
  generate a redirect link using a real `https://` URL rather than the
  mobile deep-link scheme.
- **FR-005**: Password-reset requests initiated from the mobile app MUST
  continue to use the existing mobile deep-link scheme, unchanged.
- **FR-006**: The redirect URL used for a password-reset request MUST be
  chosen automatically, at request time, based on the platform the request
  originates from — no manual or user-facing configuration required.
- **FR-007**: Completing a password reset from a Web-originated link MUST
  perform the same account-security behavior as today's mobile flow
  (signing the account out of every session globally once the new password
  is set).
- **FR-008**: The Web app's identity surfaces — browser tab title, PWA
  manifest name/short name/description, theme color, and favicon/icons —
  MUST reflect the shipped product name and branding ("Kiểm Soát") rather
  than Flutter's default scaffolding values.
- **FR-009**: The Web app's manifest MUST NOT lock the display orientation
  to a single fixed orientation, since a desktop/laptop browser window is
  freely resizable and is not a fixed-orientation device.
- **FR-010**: The Web app MUST use path-based URL routing (e.g.
  `/overview`) rather than hash-based routing (e.g. `/#/overview`) for
  every in-app route.
- **FR-011**: Loading any in-app path directly — a fresh page load or a
  deep link, not reached via in-app navigation — MUST successfully show the
  corresponding screen rather than a 404 or a blank page, given hosting
  that rewrites unknown paths to the app shell (see Assumptions).
- **FR-012**: This feature MUST NOT change any user-visible behavior on
  mobile platforms beyond what FR-005 already states is unchanged — the
  mobile app's database, password-reset redirect scheme, and app identity
  remain exactly as they are today.
- **FR-013**: The full existing automated test suite MUST continue to pass
  after this feature.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of screens that read local data (Tổng quan, Kiểm soát,
  Thu chi, Báo cáo, Lịch sử, Hồ sơ) display real account data on a Web
  build, with zero unhandled data-loading errors, verified by a full
  sign-in-to-data-visible walkthrough on Web.
- **SC-002**: A transaction or Kiểm soát edit made on Web survives a full
  page reload with no data loss, verified by an explicit write-then-reload
  check.
- **SC-003**: A password-reset request made from the Web app produces a
  redirect link whose scheme is `https://`, not the mobile app's custom
  scheme, verified by inspecting the generated URL.
- **SC-004**: Every Web identity surface (browser tab title, PWA manifest
  fields, favicon) shows "Kiểm Soát" branding, with zero remaining
  Flutter-default placeholder strings ("finance", "A new Flutter
  project."), verified by a direct inspection of each surface.
- **SC-005**: Each of the app's 5 primary navigation destinations is
  reachable both by in-app navigation and by loading its path-based URL
  directly, with no hash fragment present in the address bar at any point.
- **SC-006**: The existing automated test suite (413 tests as of this
  feature's start) passes in full after this feature, with no test's
  outcome changed as an unintended side effect.

## Assumptions

- The exact Web hosting/deployment target (and its ability to rewrite
  unknown paths back to the app shell, which path-based routing requires
  per FR-011) is not yet decided in this codebase; this feature implements
  the app-side routing change and documents the hosting requirement, but
  configuring an actual host's rewrite rule is the user's own action item
  outside this codebase — the same kind of external dependency as the
  Supabase Dashboard redirect-URL configuration below.
- The matching Supabase Dashboard change — adding the new `https://`
  Web redirect URL to the project's allowed redirect list — is the user's
  own action item outside this codebase; this feature cannot configure
  Supabase's server-side settings itself, only make the app request the
  correct URL.
- "Kiểm Soát" is treated as the app's canonical display name for Web
  identity surfaces (manifest name, page title), matching how the app is
  already referred to elsewhere in this codebase's specs and UI strings;
  no new naming decision is introduced by this feature.
- This feature does not change which platforms are supported — Android,
  iOS, and Web remain the supported set per the constitution; native
  Desktop stays deferred and untouched.
- No new user-facing setting is introduced (e.g. no manual "storage
  backend" or "URL style" toggle) — both the database fallback and the
  routing change are automatic and transparent to the user.
- This feature fixes the specific, already-documented defects listed in
  its three user stories; it does not attempt a general security or
  performance audit of the Web platform beyond what those defects cover
  (see "Out of Scope & Follow-Up Work" for the specific security-adjacent
  items deliberately deferred, and why).

## Out of Scope & Follow-Up Work

*This section is deliberately detailed and engineering-specific — unlike
the rest of this spec — for the same reason the previous feature
(adaptive-layout-foundation) recorded its own follow-up backlog this way:
so whoever picks up work after this feature ships (including a future
session with no memory of this conversation) can act on it without
re-deriving it from scratch. Each item below was explicitly scoped out when
this feature was defined, specifically so it would not silently bloat this
PR with an unrelated risk class.*

### 1. App-level PIN-entry lock for platforms without biometric

`lib/core/auth/biometric_login_repository.dart:22` (`isDeviceCapable`) and
`:33` (`authenticate`) both return `false` under `kIsWeb`, and no PIN-entry
fallback exists anywhere in the app today. The constitution's Security
section (amended in v1.5.0) states: "where biometric hardware/APIs are
unavailable (e.g. Web), the PIN path MUST still be offered — the app MUST
NOT leave that platform with no app-level lock at all." This feature does
**not** implement that PIN path — it only fixes Web's data layer (User
Story 1), auth redirect (User Story 2), and identity/routing (User Story
3). Web remains without any app-level lock after this feature ships,
same as before it.

**Why deferred**: A PIN-entry lock is a substantial new cross-platform
security feature in its own right — new UI (PIN entry/setup screens), new
local secret storage, lockout/retry policy, and its own interaction with
the existing biometric flow on platforms that have both. It is not a
Web-specific tweak, and bundling it into a data/redirect/identity fix PR
would mix an unrelated risk class into this change. It deserves its own
spec, scoped across all platforms that might lack biometric hardware, not
just Web.

**Suggested next spec**: `app-lock-pin-fallback` (or similar), written
against the constitution's existing Security-section requirement directly.

### 2. Risk-acceptance or hardening decision on Web secure storage

`lib/core/storage/secure_local_storage.dart` wraps `flutter_secure_storage`
for the Supabase session. That package's own README (checked at the
version pinned in `pubspec.lock`) states its Web implementation is
"experimental," backed by WebCrypto plus `localStorage`, and explicitly
calls out that HSTS must be correctly configured or the stored session
becomes vulnerable to a JS-injection hijack. This feature does not touch
that storage layer or make any decision about it — it only makes the
Web app's data and auth-redirect *paths* work; whatever the session token
itself is stored in in the browser stays exactly as experimental and
un-hardened as it is today.

**Why deferred**: This is a risk-acceptance or security-hardening decision
(does the team accept the documented risk, add HSTS enforcement and other
mitigations, or replace the storage mechanism on Web?), not a functional
bug with an obvious fix — mixing a security-posture decision into a
functional-fix PR would make that PR harder to review and easier to
rubber-stamp without the scrutiny the decision deserves.

**Suggested next spec**: a short risk-assessment spec (or a documented,
reviewed decision recorded directly in the constitution/security docs if
no code change results) — should happen before Web is promoted or
marketed as a primary way to use the app, since it directly affects
session-token confidentiality.

### 3. Converting `Navigator.push` call sites to real `go_router` routes

Several screens open sub-screens via
`Navigator.of(context).push(MaterialPageRoute(...))` instead of a router
route:

- `lib/features/expenses/presentation/spending_screen.dart:52,67,79`
- `lib/features/expenses/presentation/overview_screen.dart:129,392,607`
- `lib/features/account/presentation/account_screen.dart:195`

On Web these never get their own URL — no back-button support, no
bookmark/share support, and no interaction with this feature's new
path-based routing (User Story 3) beyond the top-level destinations. This
feature does **not** convert any of these call sites.

**Why deferred**: These pushes belong to screens (Thu chi's category
picker, Tổng quan's "see all"/detail pushes, Hồ sơ's sub-screens) that are
also queued for their own adaptive list-detail redesigns in
`adaptive-layout-foundation/spec.md`'s §B follow-up backlog. Converting them
to routes now, only to restructure the same screens again for list-detail
layouts shortly after, would mean doing the routing work twice. Better done
once, together, when each screen's list-detail redesign is actually
tackled.

**Suggested next spec(s)**: fold into whichever spec(s) implement
`adaptive-layout-foundation/spec.md`'s §B items (e.g.
"expense-entry-adaptive-panel" for `spending_screen.dart`,
"history-profile-list-detail" for `account_screen.dart` and the Tổng quan
detail pushes) — not a standalone routing-only spec, since the route shape
should be designed together with the layout that will use it.
