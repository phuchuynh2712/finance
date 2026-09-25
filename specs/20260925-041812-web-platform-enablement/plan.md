# Implementation Plan: Web Platform Enablement

**Branch**: `20260925-041812-web-platform-enablement` | **Date**: 2026-09-25 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from
`specs/20260925-041812-web-platform-enablement/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See
`.specify/templates/plan-template.md` for the execution workflow.

## Summary

Fix the three previously-documented, pre-existing defects that keep Web
from being "fully supported" per constitution v1.5.0: (P1, CRITICAL) the
local Drift database throws synchronously and never opens on Web at all,
because `driftDatabase(name: 'finance')` is missing the `web:` parameter
`drift_flutter` requires there — fixed by supplying `DriftWebOptions` with
a same-origin `sqlite3.wasm` + `drift_worker.js`; (P2) the password-reset
redirect is hardcoded to a mobile-only deep link — fixed by a new
build-time `WEB_PASSWORD_RESET_REDIRECT_URL` config value, chosen at
request time based on `kIsWeb`, following the app's existing
`--dart-define` configuration pattern (Clarification 1: fixed, not derived
from the browser's runtime origin); (P3) Web still presents as
unconfigured Flutter scaffolding — fixed by updating `web/manifest.json`,
`web/index.html`, and `MaterialApp.title` to the real "Kiểm Soát" identity,
removing the nonsensical portrait-orientation lock, and switching to
path-based URL routing via `usePathUrlStrategy()`. A fourth, smaller piece
falls out of P1's own lazy-connection design: since a Web storage failure
would otherwise surface unpredictably wherever a screen first queries the
database, a new `kIsWeb`-only startup warm-up check (Clarification 2)
forces it to resolve once in `main()`, showing the app's existing
startup-error screen (reused, with new copy) on failure rather than a
silent hang.

## Technical Context

**Language/Version**: Dart 3.11.0 / Flutter 3.41.0 (existing project;
toolchain confirmed installed and matching the previous feature's
verified version — no change).

**Primary Dependencies**: `drift`/`drift_flutter` (^2.22.1/^0.2.4,
resolved `drift-2.28.2`/`drift_flutter-0.2.7` — existing, no version
change; only a new call-site parameter), `flutter_web_plugins` (Flutter
SDK-bundled, already transitively resolved — promoted to a **direct**
dependency since this feature imports it directly, per research.md
Decision 6), `supabase_flutter` (existing, unchanged API surface —
`resetPasswordForEmail`'s `redirectTo` argument value changes, not its
shape), `flutter_riverpod` (existing — `UncontrolledProviderScope`,
already part of the package, newly used by this feature per research.md
Decision 9). No new package is added to `pubspec.yaml`'s dependency list
beyond promoting `flutter_web_plugins` from transitive to direct.

**Storage**: Drift/SQLite, unchanged engine and unchanged native-platform
behavior — only the previously-absent Web code path is completed (`web:
DriftWebOptions(...)`, research.md Decision 1). No schema/migration
change (`schemaVersion` stays 6).

**Testing**: `flutter analyze`, `dart format --output=none
--set-exit-if-changed lib test`, `flutter test` (currently 413 tests, all
passing — confirmed by running the full suite at this feature's start,
per spec.md SC-006). New coverage is unit/file-content-level only
(research.md Decision 10) — this session's `flutter test` runs on the
Dart VM and cannot exercise real Web-target code paths (`kIsWeb` is
compile-time-fixed to `false` there); genuine in-browser verification is
documented as a required manual step in quickstart.md, not claimed as
automated.

**Target Platform**: Android, iOS, and Web — this feature is specifically
the one that brings Web into actual constitution compliance (Multi-
Platform Support section) rather than merely not-worse-off, which is as
far as the previous feature (`adaptive-layout-foundation`) took it. Native
Desktop remains out of scope, unaffected either way.

**Project Type**: Feature-first mobile/web Flutter application (unchanged).

**Performance Goals**: The new `kIsWeb`-only startup warm-up query
(research.md Decision 9) adds one additional awaited round-trip to Web
cold start only (opening + migrating the database once) — this work was
already unavoidable before the user could see real data (User Story 1
requires it to succeed before any screen can show anything real); moving
it earlier, to a single controlled point, does not add new total work,
only makes an already-required cost explicit and centrally handled rather
than deferred to an arbitrary later screen. No mobile cold-start path is
touched (the warm-up step is skipped entirely when `!kIsWeb`).

**Constraints**: No new route/path (Navigation Contract, contracts/
web-platform-enablement.md); no change to mobile's redirect scheme, tap
targets, or layout (FR-012); the exact Web hosting target — and therefore
the two hosting-level capabilities this feature's app-side changes require
(an SPA-fallback rewrite rule for path-based routing, and correct
`application/wasm` content-typing for the new `.wasm` asset) — remain
undecided and out of this codebase's control (spec.md Assumptions,
research.md Decisions 3 and 7); `sqlite3.wasm` itself must be downloaded
from an external GitHub release this sandboxed session's own GitHub
access does not reach (research.md Decision 2) — a task-execution-time
dependency, not resolved by this plan.

**Scale/Scope**: One existing file gains a new required parameter
(`lib/core/database/app_database.dart`); one existing method gains a
platform branch (`lib/core/auth/auth_repository.dart`); one new pure
helper function (data-model.md); one existing config class gains one new
validated field (`lib/core/config/app_environment.dart`); `lib/main.dart`
gains one unconditional call (`usePathUrlStrategy()`) and one new
`kIsWeb`-gated startup step; one existing private widget
(`_StartupErrorApp`) gains a required parameter; two static config files
edited (`web/manifest.json`, `web/index.html`); two new binary/script
assets added under `web/` (`sqlite3.wasm`, `drift_worker.js`); four new
ARB string keys (`vi`+`en` × title/message). No new feature directory, no
new screen, no new route.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

- **Principle I — Code Quality: PASS.** `resolvePasswordResetRedirectUrl`
  (data-model.md) is a plain, framework-independent function outside any
  `build()`/widget, single responsibility, directly unit-testable. The
  startup warm-up step (research.md Decision 9) is a small, linear
  addition to `main()` mirroring the existing `initSupabase()` try/catch
  shape already there — no new mixed-responsibility widget introduced.
- **Principle II — Testing Standards: PASS, with an explicitly documented
  gap.** New unit/file-content coverage is added for every piece of logic
  this session's `flutter test` can actually exercise (research.md
  Decision 10, quickstart.md). The parts it cannot exercise (real
  in-browser Drift-on-Web behavior, real in-browser path routing) are
  named plainly as manual verification steps rather than silently assumed
  passing or hidden behind a misleadingly-green automated suite — this is
  a documentation/honesty requirement, not a coverage-percentage
  violation: the domain/data layer's ≥80% line-coverage gate is untouched
  by this feature (it changes zero domain logic) and the new code this
  feature *does* add (the pure redirect-resolution function, the config
  validation, the widget parameterization) is fully unit/widget-testable
  and will be tested.
- **Principle III — User Experience Consistency & Adaptive Design: N/A.**
  This feature changes no layout, breakpoint, or window-size decision —
  it is the data/auth/identity feature `adaptive-layout-foundation`'s own
  Constitution Check explicitly deferred (spec.md's inherited context).
  The one visible-UI change (`_StartupErrorApp`'s parameterization) reuses
  its exact existing visual structure unchanged, only varying which two
  translated strings it reads.
- **Principle IV — Performance: PASS.** See Technical Context's
  Performance Goals — the new Web-only warm-up cost is not new total
  work, only earlier/centralized already-necessary work; nothing runs on
  the UI isolate that didn't already (Drift's own connection machinery is
  unchanged by this feature).
- **Clean Architecture / Recommended Architecture: PASS.** The redirect
  URL decision stays inside `core/auth/` (`auth_repository.dart`), exactly
  where the constitution's Multi-Platform Support section requires
  platform-specific integration points to live; the new config field
  stays inside the existing `core/config/app_environment.dart`, not a new
  ad hoc constants file; no feature imports another feature's internals;
  no new repository, no new DI registration beyond what `main()` already
  does today for `initSupabase()`.
- **Offline-First Data & Sync: PASS — this is the feature that actually
  fulfills this section's Web mandate.** "Local database on Web: Drift
  MUST be opened with `DriftWebOptions` supplying a same-origin
  `sqlite3.wasm` and `drift_worker.js`..." is quoted directly from the
  constitution's Multi-Platform Support section and is precisely what
  research.md Decisions 1–2 implement. No change to the outbox/sync
  worker, conflict resolution, or the Supabase↔Drift↔domain mapping
  boundary — those were never the defect.
- **Multi-Platform Support: PASS — this feature is this section's own
  required follow-up, arriving as promptly as the previous feature's plan
  said it should.** All three sub-bullets this feature targets are
  addressed: "Local database on Web" (Decisions 1–2), "Platform-specific
  integration points... MUST be resolved behind the `core/auth/`... 
  abstractions" (Decision 5), and "App identity on Web... page title,
  `manifest.json`... and the URL strategy (path-based, no `#`)"
  (Decisions 6, 8) — this is close to a direct checklist match between the
  constitution's own wording and this feature's three user stories, which
  is exactly why `/speckit-analyze` flagged the underlying gap as
  CRITICAL in the first place. "Capability detection over platform
  assumption" (the PIN-fallback bullet) is explicitly **not** addressed
  here — spec.md's Out of Scope item 1 defers it to its own future spec,
  consistent with this same constitution section's capability-detection
  rule not being violated (nothing here newly assumes biometric exists —
  the existing `kIsWeb` early-`false`-return in
  `biometric_login_repository.dart` is untouched, neither better nor
  worse than before).
- **Security: PASS, with one explicitly-named residual gap unchanged.**
  The new `WEB_PASSWORD_RESET_REDIRECT_URL` value is public (a redirect
  target URL, not a secret) and follows the same `String.fromEnvironment`
  pattern already used for the (also-public) `SUPABASE_URL` — no new
  secret-handling surface. This feature does **not** touch `secure_
  local_storage.dart` or its experimental Web backend (spec.md Out of
  Scope item 2, unchanged, still open) — Web sessions are exactly as
  secured (or not) after this feature as before it; this feature only
  makes the *data* and *auth-redirect* paths function, it does not change
  what protects the session token at rest. Separately, this is the first
  feature to let Web hold real financial data at rest at all — spec.md's
  Assumptions section (added per `/speckit-analyze` finding E1) records
  why the constitution's at-rest-encryption SHOULD is satisfied the same
  way it already is on mobile (reliance on OS-level disk protection, no
  SQLCipher on any platform), not a new gap this feature introduces.
- **Development Workflow: PASS (procedural).** Feature branch discipline
  followed per the session's own branch requirement (see Project
  Structure note below); this PR's description will call out the
  Multi-Platform Support/platform-capability-detection nature of the
  change per the constitution's Development Workflow bullet, since
  `core/database/`, `core/auth/`, and `core/config/` are all shared
  `core/` utilities.

**Post-design re-check**: PASS. Phase 1 design introduces no new external
service, no new third-party package (only promotes an already-transitive
SDK-bundled one to direct), and no unapproved architecture exception. Two
items remain genuinely outside this plan's power to fully close, and are
named rather than hidden: (1) `sqlite3.wasm`'s actual binary must still be
fetched from a GitHub release this sandboxed session's own scoped GitHub
access cannot reach (research.md Decision 2) — a task-execution-time
action; (2) the eventual Web hosting target's SPA-fallback rewrite rule
and `.wasm` content-type configuration (research.md Decisions 3, 7) are
outside this codebase entirely, as already recorded in spec.md's own
Assumptions before planning began.

## Project Structure

### Documentation (this feature)

```text
specs/20260925-041812-web-platform-enablement/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md         # Phase 1 output (/speckit-plan command)
├── quickstart.md         # Phase 1 output (/speckit-plan command)
├── contracts/            # Phase 1 output (/speckit-plan command)
├── checklists/            # Spec quality checklist (/speckit-specify command)
└── tasks.md               # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
lib/
├── core/
│   ├── database/
│   │   └── app_database.dart               # MODIFIED: driftDatabase() call
│   │                                        # gains `web: DriftWebOptions(...)`
│   │                                        # (research.md Decisions 1-2)
│   ├── auth/
│   │   └── auth_repository.dart            # MODIFIED: resetPasswordForEmail's
│   │                                        # redirectTo branches on kIsWeb via
│   │                                        # the new resolvePasswordResetRedirectUrl
│   │                                        # helper (research.md Decision 5)
│   ├── config/
│   │   └── app_environment.dart            # MODIFIED: + webPasswordResetRedirectUrl
│   │                                        # field, + kIsWeb-gated validation
│   └── database/
│       # (appDatabaseProvider itself is unchanged — same file, no edit needed;
│       #  main.dart is what newly resolves it early, see below)
├── main.dart                                # MODIFIED: + usePathUrlStrategy()
│                                             # (research.md Decision 6, all
│                                             # platforms); + kIsWeb-only startup
│                                             # DB warm-up via an explicit
│                                             # ProviderContainer +
│                                             # UncontrolledProviderScope
│                                             # (research.md Decision 9);
│                                             # _StartupErrorApp gains a
│                                             # required reason parameter;
│                                             # MaterialApp.title → 'Kiểm Soát'
web/
├── manifest.json                            # MODIFIED: name/short_name/theme_color/
│                                             # description → real product identity;
│                                             # orientation key removed
│                                             # (research.md Decision 8)
├── index.html                               # MODIFIED: <title> + description meta
│                                             # → real product identity
├── sqlite3.wasm                             # NEW (binary asset — research.md
│                                             # Decision 2, task-execution-time
│                                             # download)
└── drift_worker.js                          # NEW (compiled asset — research.md
│                                             # Decision 2, `dart compile js`,
│                                             # offline)
pubspec.yaml                                  # MODIFIED: flutter_web_plugins promoted
│                                              # from transitive to direct dependency
lib/core/l10n/
├── app_vi.arb                                # MODIFIED: + startupWebStorageTitle/
│                                              # Message (data-model.md)
└── app_en.arb                                # MODIFIED: same, English
test/
├── unit/core/config/
│   └── app_environment_test.dart             # NEW: webPasswordResetRedirectUrl
│                                              # validation (research.md Decision 10)
├── unit/core/auth/
│   └── (extended or new file)                # NEW/EXTENDED: resolvePasswordResetRedirectUrl
│                                              # unit tests, both isWeb branches
├── unit/web/ or unit/core/
│   └── web_identity_test.dart                # NEW: manifest.json/index.html
│                                              # content assertions (file-based,
│                                              # no browser — research.md Decision 10)
└── widget/
    └── startup_error_app_test.dart           # NEW: both _StartupFailureReason
                                               # variants render distinct copy
```

**Structure Decision**: No new feature directory and no new route — every
change lands inside `core/database/`, `core/auth/`, `core/config/`, and
`main.dart`/`web/`, matching the constitution's Recommended Architecture
placement for exactly these concerns (database, auth integration points,
build-time config, app identity). This feature does not create
`specs/20260925-041812-web-platform-enablement`'s git branch as a real git
branch — consistent with the session's branch note in spec.md's header;
all work stays on the session-designated `claude/sweet-fermi-yd1qj8`.

## Phase 0: Research Summary

Research is recorded in [research.md](./research.md). Ten decisions were
made, each grounded against packages/SDK actually installed in this
session rather than assumed from memory: reading `drift_flutter-0.2.7`'s
own source confirmed the exact synchronous `ArgumentError` mechanism
behind the P1 defect and the exact fix shape (Decision 1); reading
`drift-2.28.2`'s bundled `web/drift_worker.dart` and `sqlite3-2.9.4`'s own
README resolved how `drift_worker.js` (compiled locally, no network) and
`sqlite3.wasm` (must be downloaded — this session's GitHub access is
scoped too narrowly to do it here) are obtained (Decision 2); the Web
hosting-level dependencies this feature's app-side changes require
(`.wasm` content-type, SPA-fallback rewrite) are named but deliberately
left unresolved, since no host is chosen yet (Decisions 3, 7); the
already-established `AppEnvironment`/`--dart-define` pattern is reused,
`kIsWeb`-gated, for the new redirect URL rather than deriving it from the
browser's origin, per Clarification 1 (Decision 5); reading the installed
Flutter SDK's `flutter_web_plugins` source confirmed `usePathUrlStrategy()`
is a documented no-op on non-web platforms, safe to call unconditionally
(Decision 6); the existing verified brand color is reused for
`manifest.json`'s theme color rather than inventing a new one (Decision
8); reading `driftDatabase()`'s Web implementation revealed its *lazy*
`Future`-based connection, which is why FR-014/Clarification 2 needs an
explicit startup warm-up step (via Riverpod's own
`ProviderContainer`/`UncontrolledProviderScope` pattern) rather than
relying on whichever screen happens to query first, and why
`_StartupErrorApp` needs parameterizing rather than reusing its
Supabase-specific copy verbatim (Decision 9); and a frank assessment of
what this sandboxed session's `flutter test` (Dart VM only) can and
cannot verify, matching the previous feature's own honest T030 precedent
rather than claiming untested behavior as verified (Decision 10).

## Phase 1: Design Summary

- [data-model.md](./data-model.md) defines the new configuration/value
  surface this feature introduces (`AppEnvironment.
  webPasswordResetRedirectUrl`, `resolvePasswordResetRedirectUrl`,
  `_StartupFailureReason`) — no persisted schema, no domain entity.
- [contracts/web-platform-enablement.md](./contracts/web-platform-enablement.md)
  documents the one real external gateway contract this feature touches
  (Supabase's `resetPasswordForEmail`, new `redirectTo` value only), the
  changed `driftDatabase()` call contract, the parameterized
  `_StartupErrorApp` presentation contract, the new startup sequence
  contract, and an explicit confirmation that no new route/path is
  introduced.
- [quickstart.md](./quickstart.md) lists manual, post-deployment
  verification steps for everything this sandboxed session's automated
  suite cannot itself exercise (real in-browser Drift-on-Web behavior,
  real in-browser path routing, the real password-reset email round-trip)
  alongside the automated regression coverage this feature does add and
  can run here.
- `CLAUDE.md`'s plan reference is updated to point at this plan (Phase 1
  step 3), so the next session's context load reflects this feature
  instead of the now-shipped/merged Adaptive Layout Foundation feature.

## Complexity Tracking

No constitution violations *caused by this feature's own design* require
justification here. The two items named in the Constitution Check's
post-design re-check (the `sqlite3.wasm` download needing network access
this session's GitHub scope does not extend to, and the undecided Web
hosting target's own configuration) are pre-existing environmental/
infrastructure boundaries, not complexity this feature's design chose to
introduce — both are already tracked as explicit action items (spec.md
Assumptions; research.md Decisions 2–3, 7), not smuggled in silently.
