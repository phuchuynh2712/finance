# Phase 0 Research: Web Platform Enablement

All decisions below are grounded against the packages and SDK actually
installed in this session (`/root/.pub-cache`, `/opt/flutter`), not
assumed from memory, per this project's established research discipline.

## Decision 1: How to open Drift on Web (P1 / FR-001–FR-003)

**Decision**: Pass `web: DriftWebOptions(sqlite3Wasm: Uri.parse
('sqlite3.wasm'), driftWorker: Uri.parse('drift_worker.js'))` to the existing
`driftDatabase(name: 'finance')` call in `lib/core/database/app_database.dart:12`.
Both URIs are same-origin, relative paths into the app's own `web/`
directory (no CDN, per constitution's Multi-Platform Support section).

**Rationale**: Read directly from the installed `drift_flutter-0.2.7`
package source (`lib/src/web.dart`): the Web-compiled variant of
`driftDatabase()` throws `ArgumentError('When compiling to the web, the
`web` parameter needs to be set.')` synchronously whenever `web` is
`null` — this is the exact, confirmed mechanism of the P1 defect (not
inferred, read from source). Supplying it removes the throw and routes to
`WasmDatabase.open(databaseName: name, sqlite3Uri: web.sqlite3Wasm,
driftWorkerUri: web.driftWorker, ...)`, which drift's own web support
selects the best available storage backend for automatically (OPFS when
cross-origin-isolation headers are present, IndexedDB otherwise) —
satisfying FR-003's fallback requirement with no extra app code; the
`WasmDatabaseResult.missingFeatures` callback (`onResult`) is available if
degraded-mode logging is ever wanted, but nothing in this feature's FRs
requires surfacing that to the user, so it is left as the package default
(a debug-only `print`) rather than adding new UI.

**Alternatives considered**: A third-party IndexedDB-only wrapper —
rejected, `drift_flutter`/`drift` is already the project's chosen local-
database toolkit (Offline-First Data & Sync section) and already supports
Web natively; introducing a second database library for one platform would
violate the constitution's single-source-of-truth local DB mandate and
dependency-hygiene rule.

## Decision 2: Obtaining `sqlite3.wasm` and `drift_worker.js` (P1)

**Decision**: `drift_worker.js` is compiled **locally, offline, with no
network access**, via `dart compile js -o web/drift_worker.js
<path-to-drift-package>/web/drift_worker.dart` (the standard Dart-to-JS
compiler, already part of the installed Dart SDK). `sqlite3.wasm` cannot be
produced this way — it is a precompiled WebAssembly binary — and must be
downloaded from the `sqlite3` Dart package's GitHub releases, matching the
`sqlite3: 2.9.4` version already pinned in `pubspec.lock`, into `web/
sqlite3.wasm`.

**Rationale**: Confirmed directly against the installed packages, not the
(network-inaccessible in this session) drift.simonbinder.eu docs the
`drift_flutter` README points to:
- `/root/.pub-cache/hosted/pub.dev/drift-2.28.2/web/drift_worker.dart`
  exists and is exactly a 4-line entrypoint (`void main() {
  WasmDatabase.workerMainForOpen(); }`) — precisely the kind of file
  `dart compile js` turns into a worker script, with zero network
  dependency since the source is already on disk.
- `/root/.pub-cache/hosted/pub.dev/sqlite3-2.9.4/README.md` (§ WASM (web
  support)) explicitly instructs "just grab the `.wasm` from the latest
  release on GitHub" for the package's own test setup — there is no
  bundled copy shipped inside the pub package for direct reuse (the one
  `sqlite3.wasm` found in this pub-cache, under `drift-2.28.2/extension/
  devtools/build/`, belongs to Drift's own DevTools browser extension
  build and is not a general-purpose redistributable asset).
- This session's GitHub access is scoped to `phuchuynh2712/finance` only
  (confirmed: `curl` to `api.github.com` for the unrelated
  `simolus3/sqlite3.dart` repo was refused by this session's own GitHub
  proxy) — so the actual binary download is **out of Phase 0 research's
  reach** and must happen as a task-execution-time step (`/speckit-tasks`
  should generate a task that performs this download, or documents the
  exact command for the user/CI to run if this session still cannot reach
  `github.com` by then).

**Alternatives considered**: Building `sqlite3.wasm` from source via the
`sqlite3` package's own `Makefile`/emscripten toolchain (referenced in its
README) — rejected as unnecessary complexity; downloading the
already-built release asset is the documented, standard path every
`drift_flutter` consumer uses.

## Decision 3: Serving `.wasm` with the correct Content-Type (P1)

**Decision**: Documented as a **hosting-configuration dependency**,
alongside the SPA-fallback-rewrite-rule dependency already recorded in
spec.md's Assumptions — not resolved inside this codebase, since the exact
Web host is not yet chosen (confirmed: no `netlify.toml`, `firebase.json`,
`vercel.json`, `nginx.conf`, or `Dockerfile` exists anywhere in this
repository today).

**Rationale**: `flutter build web`'s output is static files; it does not
control the HTTP response headers a production host serves them with.
Most modern static hosts already default `.wasm` to
`application/wasm` correctly, but this cannot be verified without a
chosen host. Consistent with how spec.md already treats the Supabase
Dashboard redirect-allowlist change and the SPA-fallback rule as the
user's own action items outside this codebase.

**Alternatives considered**: None — this is fundamentally a deployment
concern, not an application-code decision.

## Decision 4: COOP/COEP headers for OPFS (P1, optional enhancement)

**Decision**: Not pursued in this feature. FR-003's IndexedDB fallback
(Decision 1) already satisfies every functional requirement without it.

**Rationale**: The constitution itself frames COOP/COEP as optional
("optionally add COOP/COEP response headers to unlock the faster OPFS
storage backend instead of the IndexedDB fallback"). Like Decision 3,
these are response headers the eventual host must set — not something
`flutter build web`'s static output can configure — so pursuing this now,
before a host is chosen, would be speculative. Recorded here so a future
session doesn't have to rediscover that OPFS is possible, just not
required.

## Decision 5: Password-reset redirect URL (P2 / FR-004–FR-007, Clarification 1)

**Decision**: Add a new build-time constant to the existing
`lib/core/config/app_environment.dart`:
`static const webPasswordResetRedirectUrl = String.fromEnvironment
('WEB_PASSWORD_RESET_REDIRECT_URL');`, validated (non-empty, valid
`https://` URI) inside `AppEnvironment.validate()` **only when `kIsWeb`**.
`lib/core/auth/auth_repository.dart`'s `resetPasswordForEmail` branches:
`redirectTo: kIsWeb ? AppEnvironment.webPasswordResetRedirectUrl :
'com.finance.finance://reset-callback'`. The actual production URL value
is supplied at build time via `--dart-define`/`--dart-define-from-file`,
matching Clarification 1's "single, fixed URL, not derived from the
browser's runtime origin" decision.

**Rationale**: `lib/core/config/app_environment.dart` and `lib/core/
network/supabase_client_provider.dart:9-11` already establish this exact
pattern for `SUPABASE_URL`/`SUPABASE_PUBLISHABLE_KEY` — reusing it keeps
one consistent configuration mechanism (no new config system introduced)
and satisfies the constitution's Multi-Platform Support rule that
"platform-specific integration points (OAuth/password-reset redirect
URLs...) MUST be resolved behind the `core/auth/`... abstractions." Gating
`validate()`'s check to `kIsWeb` is required, not optional: `validate()`
runs unconditionally in `initSupabase()` on every platform including
mobile (`lib/main.dart`), and an ungated required-non-empty check would
break every mobile build (which has no reason to supply this define) —
this would violate FR-012's "MUST NOT change any user-visible behavior on
mobile platforms." No real production domain exists anywhere in this
repository yet (confirmed: no README/env-file/build-config reference to
one) — this is expected and consistent with spec.md's Assumptions (the
Web hosting target itself is undecided); the `--dart-define` mechanism
means the actual literal domain is supplied at build/deploy time, not
guessed or hardcoded into source now.

**Alternatives considered**: Deriving from `Uri.base` at runtime —
rejected per Clarification 1 (security: avoids trusting a browser-supplied
origin for a sensitive auth redirect, and the project has no
multi-environment hosting setup that would need it). A new dedicated
`.env`-style file — rejected; `README.md` and `supabase_client_provider.
dart:10` already establish `--dart-define-from-file=tool/env.json`
(`tool/env.json`, gitignored, created from the tracked `tool/
env.example.json`) as this project's one configuration mechanism, holding
today only `SUPABASE_URL`/`SUPABASE_PUBLISHABLE_KEY` — `WEB_PASSWORD_
RESET_REDIRECT_URL` is added to that same file/example, not a new one.

**Addendum — localhost exemption**: `README.md:89-90` already documents a
local Web dev workflow at a **fixed origin**
(`flutter run -d chrome --web-port=5000 ...`) with an instruction to add
that fixed origin to Supabase's allowed redirect list — confirming fixed-
origin Web dev is already this team's practice, not a new idea introduced
by this feature. That fixed local origin is `http://localhost:5000`, not
`https://`. Strictly requiring `https` in `AppEnvironment.validate()`
(as first drafted above) would therefore break local Web development the
moment someone actually fills in `tool/env.json` from the new example key,
which is a real usability defect, not a theoretical one. Fix: the
validation accepts `https` unconditionally, **or** `http` when the host is
exactly `localhost`/`127.0.0.1` — the same narrow, well-established
loopback exemption OAuth redirect-URI validation commonly uses (e.g. RFC
8252 §7.3 exempts loopback interface redirect URIs from requiring TLS).
Production/any real deployed origin still MUST be `https`; only the
literal loopback address is exempted. `tool/env.example.json`'s new key
gets the `http://localhost:5000/...` value as its example default,
matching `README.md`'s already-documented local port.

## Decision 6: Path-based URL strategy (P3 / FR-010, FR-011)

**Decision**: Call `usePathUrlStrategy()` (from `package:flutter_web_plugins/
url_strategy.dart`) once, unconditionally, early in `lib/main.dart`'s
`main()` — before `initSupabase()`/`runApp()`, no `kIsWeb` guard needed.
Add `flutter_web_plugins` as a **direct** dependency in `pubspec.yaml`
(`sdk: flutter`) since it will now be imported directly, even though it
already resolves transitively today.

**Rationale**: Confirmed by reading the installed Flutter SDK source
(`/opt/flutter/packages/flutter_web_plugins/lib/src/navigation_non_web/
url_strategy.dart:87-89`): `usePathUrlStrategy()` is `// No-op in
non-web platforms` in the non-web variant selected by conditional export
(`export 'src/navigation_non_web/url_strategy.dart' if
(dart.library.ui_web) 'src/navigation/url_strategy.dart';`) — so calling
it unconditionally is safe on mobile and requires no guard, keeping the
change minimal (FR-012). On the Web-compiled variant it calls
`setUrlStrategy(PathUrlStrategy())`, switching `GoRouter`'s underlying
history integration from the hash-based default to path-based, satisfying
FR-010 with no `GoRouter` configuration change needed (`go_router` already
reads whichever `UrlStrategy` is set).

**Alternatives considered**: None — this is Flutter's own documented,
single mechanism for this exact requirement; no third-party package
exists or is needed.

## Decision 7: Serving a path-based deep link directly (P3 / FR-011)

**Decision**: Same treatment as Decisions 3–4 — documented as a required
hosting capability (an SPA-fallback/rewrite rule serving `index.html` for
any unknown path) in spec.md's Assumptions and Edge Cases, not solved
inside this codebase, since the exact host is undecided.

**Rationale**: Consistent with spec.md's own Assumptions section, already
written during `/speckit-clarify`/`/speckit-specify`. No speculative
per-host config file (e.g. a Netlify `_redirects` or `firebase.json`) is
added, since guessing a host that hasn't been chosen would be invented
scope, not a real fix.

## Decision 8: Web app identity (P3 / FR-008, FR-009)

**Decision**: Direct content edits, no new mechanism needed:
- `web/manifest.json`: `name`/`short_name` → "Kiểm Soát"; `theme_color`/
  `background_color` → the app's actual brand primary
  (`0xFF1A72E0` light scheme primary, per `test/unit/core/theme/
  app_theme_test.dart`'s already-asserted value — reusing the existing
  verified brand color rather than inventing a new one); `description` →
  a real one-line description of the app; `orientation` key removed
  entirely (FR-009 — a resizable desktop/browser window has no single
  correct orientation; omitting the key, rather than setting `"any"`,
  matches the [Web App Manifest spec's own default](
  https://developer.mozilla.org/docs/Web/Manifest/orientation) of
  unrestricted orientation).
- `web/index.html`: `<title>` and the `description`/
  `apple-mobile-web-app-title` meta content → "Kiểm Soát", matching
  `manifest.json`.
- `lib/main.dart:60`: `MaterialApp.title: 'Finance'` → `'Kiểm Soát'`
  (this is the OS task-switcher/browser-tab title source on some
  platforms — kept in sync with the two files above).

**Rationale**: Minimal, direct, no ambiguity — these are static content
fields, not logic. Reusing the already-verified brand primary color
(rather than picking a new one) keeps a single source of visual truth
between the in-app theme and the browser chrome color, and needs no new
design decision.

**Alternatives considered**: A separate brand-color constant duplicated
into `manifest.json` by hand with no link back to `AppTheme` — rejected;
`manifest.json` is a static file Flutter Web reads before Dart even runs,
so it cannot literally import `AppTheme`, but citing the exact existing,
tested hex value (rather than eyeballing a new one) keeps them from
drifting apart.

## Decision 9: Surfacing a total Web storage failure (FR-014, Clarification 2)

**Decision**: In `lib/main.dart`'s `main()`, after `initSupabase()`
succeeds, and **only when `kIsWeb`**, construct an explicit
`ProviderContainer`, resolve `appDatabaseProvider` through it, and `await`
a trivial warm-up query (e.g. `customStatement('SELECT 1')`) against the
resulting `AppDatabase` inside a `try`/`on Object` guard — mirroring the
existing `initSupabase()` try/catch immediately above it. On failure, show
a parameterized version of the existing `_StartupErrorApp` (new
title/message ARB keys, not the Supabase-specific ones) and return, exactly
as the Supabase-init failure path already does. On success, pass the same
`ProviderContainer` into `runApp(UncontrolledProviderScope(container:
container, child: const FinanceApp()))` instead of a fresh implicit
`ProviderScope`, so the warm-up isn't wasted work — the app reuses the
exact `AppDatabase` instance it already opened.

**Rationale**: Read `driftDatabase()`'s Web implementation directly
(Decision 1's source): it returns `DatabaseConnection.delayed(Future(()
async { ... }))` — the actual `WasmDatabase.open(...)` call, and therefore
any storage-backend failure, happens **lazily**, only when a query first
runs against the connection, not synchronously in `AppDatabase()`'s
constructor. Left alone, a total storage failure (FR-014's edge case)
would surface as an uncaught/unhandled async error wherever in the widget
tree a screen happens to first query the database — inconsistent,
un-testable, and not the single, predictable "startup-error screen"
behavior Clarification 2 decided on. Forcing the lazy connection to
resolve once, at a controlled point in `main()`, before any real screen is
shown, is what makes FR-014 actually deliverable as a single, reliable
behavior rather than "whichever screen happens to query first."
`UncontrolledProviderScope` is Riverpod's own documented mechanism for
exactly this "do async work with a container before `runApp`, then hand
that same container to the widget tree" pattern (`flutter_riverpod` is
already the project's chosen state-management package — no new
dependency). The `_StartupErrorApp` widget's existing title/message are
hardcoded to Supabase-specific copy ("Set the public Supabase URL and
publishable key...", `startupConfigurationTitle`/`Message` in `app_vi.arb`/
`app_en.arb`) — reusing them verbatim for a storage failure would show
factually wrong text, so the widget needs a small parameterization (an
internal reason/variant switch choosing which l10n getters to read) rather
than a literal copy-paste, while keeping its exact visual structure
(icon + title + centered message) as the "existing startup-error screen"
Clarification 2 asked for.

Explicitly scoped to `kIsWeb` only (not run on mobile) because FR-012
prohibits this feature from changing mobile's current (uncaught-if-it-
ever-happened) behavior — this is new Web-only defensive behavior, not a
cross-platform change.

**Alternatives considered**: A `FutureBuilder` wrapping `FinanceApp`'s
content — rejected; it would show every screen's widgets loading state
change shape for a check that should be invisible on the (overwhelmingly
common) success path, and doesn't as cleanly reuse the exact
try/catch-then-`runApp`-something-else shape the Supabase check already
established immediately above it in the same function. Catching the
error ad hoc inside whichever repository first queries the database —
rejected; that would require every data-reading screen to independently
implement the same fallback UI, duplicating logic FR-014 intends to
centralize once.

## Decision 10: Testing strategy for Web-only code paths

**Decision**: Extract every Web/mobile branching decision into small,
pure functions or directly-injectable parameters that a VM-based `flutter
test` run can exercise with an explicit `true`/`false` flag, rather than
depending on the real `kIsWeb` constant (which cannot be toggled inside a
VM test process). Concretely: a pure `resolvePasswordResetRedirectUrl
({required bool isWeb, required String webRedirectUrl, required String
mobileRedirectUrl})`-shaped function (Decision 5) unit-tested with both
`isWeb: true` and `isWeb: false`; `AppEnvironment.validate()`'s new
Web-only branch unit-tested by calling it with an injected platform flag
rather than the real `kIsWeb`; `web/manifest.json`/`web/index.html`'s
content verified by a plain file-content assertion test (parsing the
JSON/HTML text directly — no browser needed) rather than a live render.

The actual Drift-on-Web wiring (Decision 1: does `sqlite3.wasm` really
load, does OPFS/IndexedDB really open) and the actual in-browser routing
behavior (Decision 6: does the address bar really show a path, not a
hash) **cannot** be exercised by this repository's existing `flutter
test` suite, which runs on the Dart VM (no `dart.library.js_interop`,
`kIsWeb == false` unconditionally) — only Flutter's separate `flutter
test --platform=chrome` browser-based runner could, and this session
found no standalone Chrome/Chromium binary registered for it (only a
`chromedriver` at `/opt/node22/bin/chromedriver`, and Playwright's own
sandboxed Chromium under `/opt/pw-browsers/`, which `flutter`'s own test
runner does not know how to target without extra wiring this feature does
not need to build). This mirrors the previous feature's honestly-
documented T030 finding (`flutter build web`'s default asset bootstrap
reaches a host — `www.gstatic.com` — blocked by this session's own
organization network policy). **This feature's plan therefore states
plainly, per the constitution's "Every new feature's plan MUST state
whether it was verified on Web" requirement: automated verification in
this session is limited to (a) the extracted pure-logic unit tests above
and (b) a static `flutter build web` output inspection (confirming
`sqlite3.wasm`/`drift_worker.js` are present and confirming
`manifest.json`/`index.html` content) — real in-browser dynamic behavior
(does the database actually open, does a reloaded path-based URL actually
work) requires manual verification against a real deployed build, which
is outside this sandboxed session's reach and is called out as a
required manual step in quickstart.md, not silently assumed to pass.**

**Alternatives considered**: Setting up `flutter test --platform=chrome`
end-to-end in this session (installing/registering a Chrome binary,
wiring `CHROME_EXECUTABLE`) — considered and rejected for this feature;
it is genuine test-infrastructure work orthogonal to the three P1–P3
defects this feature fixes, would risk re-hitting the same network-policy
wall the previous feature already hit and documented, and is better
scoped as its own explicit infrastructure task if the team decides
in-browser automated testing is worth the investment — not silently
bundled into this bugfix feature.
