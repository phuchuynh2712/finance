# Quickstart: Web Platform Enablement Verification

## Prerequisites

- Run from the repository root with Flutter dependencies available
  (`flutter pub get`).
- `web/sqlite3.wasm` and `web/drift_worker.js` must be present (Setup
  phase tasks — research.md Decisions 1–2) before any Web-specific manual
  check below is meaningful.
- A build-time value for `WEB_PASSWORD_RESET_REDIRECT_URL` (e.g.
  `--dart-define=WEB_PASSWORD_RESET_REDIRECT_URL=https://<real-host>/
  reset-callback`, once a real Web host is chosen — see spec.md
  Assumptions) to manually exercise User Story 2 end-to-end; without it,
  User Story 2 is only verifiable at the unit-test level (research.md
  Decision 10).
- A signed-in test user with at least a little data (any account) — this
  feature does not depend on specific transaction/budget content.

## Verification Flow

1. **Data loads on Web (User Story 1)** — run a Web build
   (`flutter run -d chrome` or an equivalent served `flutter build web`
   output) against a real or local Supabase project, sign in, and confirm
   Tổng quan shows the same real balances/groups the same account shows
   on mobile — not an error, not a permanently empty state (Acceptance
   Scenario 1).
2. **Write survives reload (User Story 1)** — on that same Web session,
   record a transaction or edit a Kiểm soát formula, then fully reload the
   page. Confirm the change is still there (Acceptance Scenario 2).
3. **Storage fallback (User Story 1)** — if feasible, test in a browser
   configuration without cross-origin-isolation headers (the common case,
   since Decision 4 does not pursue COOP/COEP) and confirm the app still
   opens correctly via the IndexedDB fallback, not just OPFS (Acceptance
   Scenario 4).
4. **Password reset from Web (User Story 2)** — with
   `WEB_PASSWORD_RESET_REDIRECT_URL` set to a real, Supabase-allow-listed
   `https://` URL, trigger "forgot password" from the Web app and confirm
   the emailed link's `redirectTo` targets that URL, not the mobile deep
   link (Acceptance Scenario 1); separately, trigger the same flow from
   the mobile app and confirm its link is unchanged (Acceptance Scenario
   2). Complete a reset from the Web-opened link and confirm the global
   sign-out behavior matches mobile's existing behavior (Acceptance
   Scenario 3).
5. **Web identity (User Story 3)** — open the Web build and check the
   browser tab title, the favicon, and (if installed as a PWA) the
   install prompt's name/icon: all MUST show "Kiểm Soát" branding, not
   "finance"/Flutter defaults (Acceptance Scenario 1).
6. **Path-based URLs (User Story 3)** — navigate to a specific screen (e.g.
   Kiểm soát) and confirm the address bar shows a clean path (e.g.
   `/expense-control`), not a `#`-prefixed hash (Acceptance Scenario 2).
   Copy that URL, open it in a fresh tab (a true cold load, not in-app
   navigation) against hosting that has the required SPA-fallback rewrite
   rule configured (spec.md Assumptions), and confirm it loads the correct
   screen rather than a 404 (Acceptance Scenario 3).
7. **Orientation unlocked (User Story 3)** — resize the browser window to
   a landscape and then a portrait aspect ratio; confirm the app is not
   forced into or blocked from either (Acceptance Scenario 4).
8. **Total storage failure shows the startup-error screen (FR-014,
   Clarification 2)** — if feasible, simulate a browser that blocks all
   local storage (e.g. a browser flag or a locked-down private-browsing
   mode known to block IndexedDB) and confirm the app shows the
   startup-error screen (new copy, not the Supabase-configuration text)
   rather than hanging or crashing.
9. **Mobile regression check (FR-012)** — run the existing mobile app
   (Android/iOS) and confirm sign-in, data loading, and password reset
   all behave exactly as before this feature — no `WEB_PASSWORD_RESET_
   REDIRECT_URL` define needed, no new startup delay, no new screen.

## What This Session Cannot Verify Automatically

Per research.md Decision 10: this repository's `flutter test` suite runs
on the Dart VM (`kIsWeb` always `false`), and this sandboxed session has
no working `flutter test --platform=chrome` setup and previously hit an
organization-policy network block reaching a host Flutter Web's default
bootstrap needs (`www.gstatic.com`, documented in the previous feature).
Steps 1–4, 6, and 8 above are therefore **manual, post-deployment**
verification steps, not steps this feature's automated task list can mark
complete — `/speckit-tasks` should reflect this distinction rather than
generating an automated test task it cannot actually satisfy in this
environment.

## Required Automated Regression Coverage

- `test/unit/core/config/app_environment_test.dart` (new) —
  `webPasswordResetRedirectUrl` validation: valid `https://` value passes,
  empty/non-`https`/unparseable values fail, all gated behind an injected
  Web flag rather than the real `kIsWeb` (research.md Decision 10).
- `test/unit/core/auth/...` (extended or new) —
  `resolvePasswordResetRedirectUrl` unit tests for both `isWeb: true` and
  `isWeb: false` (data-model.md).
- A file-content test asserting `web/manifest.json`'s `name`,
  `short_name`, `theme_color`, `description` match the shipped product and
  that no `orientation` key remains, plus `web/index.html`'s `<title>`
  text — parsed directly as JSON/text, no browser needed (research.md
  Decision 10).
- A widget test for `_StartupErrorApp` confirming each
  `_StartupFailureReason` renders its own distinct title/message pair
  (data-model.md).
- Full existing suite (413 tests as of this feature's start — mirrors
  spec.md SC-006) stays green: `flutter analyze`, `dart format
  --output=none --set-exit-if-changed lib test`, `flutter test`.
