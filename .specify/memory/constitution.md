<!--
Sync Impact Report
Version change: 1.4.0 → 1.5.0 (MINOR: new "Multi-Platform Support" section +
  materially expanded Principle III guidance; no principle redefined or removed)
Modified principles:
  - III. User Experience Consistency → III. User Experience Consistency &
    Adaptive Design: added a window-size-driven adaptive layout mandate
    (Material window size class breakpoints, bottom-bar→rail navigation switch,
    content max-width on wide windows, ≥48×48dp touch target enforced even on
    desktop's default compact density, hover/tooltip/keyboard support once a
    screen is reachable off a touch-only platform); rationale extended to cover
    cross-platform trust, not only cross-screen trust
  - II. Testing Standards → added a pinned default test-viewport requirement and
    compact/expanded breakpoint coverage for screens with adaptive layout
  - IV. Performance Requirements → clarified that budgets apply per supported
    platform (incl. Web/Desktop) against that platform's own realistic baseline,
    not silently relaxed for a newly added platform
Added sections:
  - Multi-Platform Support: Web promoted to a fully supported target (not a
    stretch goal); Desktop (Windows/macOS/Linux) declared optional/deferred but
    architecturally unblocked; Drift-on-Web (`DriftWebOptions`) mandate;
    capability-detection-over-platform-assumption rule; platform-isolation for
    auth/storage integration points; Web app-identity (title/manifest/URL
    strategy) requirement
Modified sections:
  - Recommended Architecture → `theme/` bullet now explicitly includes adaptive
    layout/window-size tokens, not just color/typography/spacing
  - Security → app-level lock bullet now explicitly requires the PIN fallback on
    any platform lacking biometric hardware/APIs (e.g. Web), cross-referencing
    Multi-Platform Support
  - Development Workflow → breaking-change call-out bullet now also names
    breakpoint changes and platform-capability-detection changes
Removed sections: none
Templates requiring updates:
  - .specify/templates/plan-template.md: ✅ compatible (Target Platform and
    Constitution Check are already filled per-feature from this file; no
    template edit needed)
  - .specify/templates/spec-template.md: ✅ compatible (no constitution-specific
    references)
  - .specify/templates/tasks-template.md: ✅ compatible (Path Conventions already
    platform-generic)
  - .specify/templates/commands/*.md: not present in this project
Follow-up TODOs:
  - README.md's tech-stack/setup section still reads mobile-first (Android
    Studio/Xcode only); worth a follow-up doc pass once the first Web-targeting
    feature lands, not required to unblock this amendment
-->

# Finance App Constitution
<!-- Personal/multi-user finance application built with Flutter -->

## Core Principles

### I. Code Quality
All code MUST pass static analysis (`flutter analyze`) with zero errors and zero
warnings before merge. The project MUST use `flutter_lints` (or a stricter
superset) with no lint rules silently disabled without a documented reason in
the same commit. Every public class, method, and widget MUST have a single,
well-defined responsibility — widgets that mix data-fetching, business logic,
and presentation MUST be decomposed. Business logic (calculations, validation,
state transitions) MUST NOT live inside `build()` methods; it belongs in
testable, framework-independent Dart classes (services, use cases, notifiers).
Code review by at least one other contributor (or a documented self-review
checklist for solo work) is REQUIRED before merging to the main branch.
Dead code, commented-out blocks, and TODO-without-ticket MUST NOT be merged.

**Rationale**: A finance app manipulates users' money and sensitive data;
unreviewed or poorly structured code compounds into calculation bugs and data
corruption that are costly and embarrassing to fix after the fact. Separating
logic from widgets is also what makes the Testing Standards principle below
achievable.

### II. Testing Standards
Every feature MUST ship with automated tests before it is considered done:
unit tests for all business logic (financial calculations, budget rules,
currency/rounding, date handling), widget tests for all reusable UI
components and screens, and integration tests for critical user flows
(onboarding, adding/editing a transaction, viewing balances, sync/import).
Line coverage for the `lib/` business-logic layers (domain + data) MUST NOT
drop below 80%; UI-layer coverage is expected but not gated at the same
threshold. Tests MUST be written or updated in the same pull request as the
behavior they cover — no "add tests later" follow-ups for financial logic.
A failing test suite MUST block merge; flaky tests MUST be fixed or
quarantined with a tracked issue, never silently ignored. Golden/screenshot
tests SHOULD be used for widgets where pixel-level regressions matter
(charts, balance summaries). The test suite MUST pin an explicit default
test viewport (rather than relying on the test framework's default size) so
existing tests do not silently change meaning as adaptive breakpoints are
introduced; any screen with breakpoint-dependent layout MUST have widget or
golden coverage at both a compact (<600dp) and an expanded (≥840dp) width,
per Principle III.

**Rationale**: Correctness of money math is non-negotiable — an unnoticed
rounding or sign error erodes user trust immediately. High coverage in the
domain layer is achievable precisely because Principle I keeps that logic
separate from Flutter widgets.

### III. User Experience Consistency & Adaptive Design
The app MUST implement a single, centralized design system (shared
`ThemeData`, spacing/typography/color tokens, and a common widget library)
that all screens consume — no screen may hardcode colors, font sizes, or
spacing values that bypass the theme. Both light and dark mode MUST be
supported and visually verified for every new screen. Navigation patterns,
error states, empty states, loading states, and confirmation dialogs (e.g.
before deleting a transaction) MUST follow the same reusable patterns across
the app; a new screen MUST NOT invent a bespoke pattern where an existing one
applies. All interactive elements MUST meet WCAG 2.1 AA contrast and touch
target size (≥48x48dp), and MUST be reachable via screen readers
(Semantics labels on custom widgets). Financial figures MUST always be
formatted consistently (locale-aware currency, sign, and decimal rules) via
a single shared formatting utility — never ad hoc string interpolation.

**Adaptive Layout**: Layout decisions MUST be driven by the available window
size, never by device or platform type — `Platform.is*`, `kIsWeb`, and
`defaultTargetPlatform` MUST NOT be used to choose a screen's layout (they
MAY still be used for genuine platform-capability checks, e.g. whether
biometric hardware exists — see Multi-Platform Support). The app MUST use
Material's window size classes as its single reference breakpoint scale —
compact (<600dp), medium (600–839dp), expanded (840–1199dp), large
(1200–1599dp), extra-large (≥1600dp) — defined once as shared tokens in
`core/theme/` and consumed via `MediaQuery.sizeOf`/`LayoutBuilder`, never
re-derived ad hoc per screen. Primary navigation MUST switch from a bottom
navigation bar below 600dp to a navigation rail at 600dp and above; a
navigation drawer MUST NOT be used. Content MUST NOT stretch unbounded at
wide window sizes — screens MUST cap content width at a shared max-width
token and center it, rather than letting a single-column mobile layout
stretch edge-to-edge on a tablet, desktop, or web window. The ≥48×48dp touch
target minimum above applies on every platform and window size, including
desktop and web; Flutter's default desktop `VisualDensity`/
`MaterialTapTargetSize` (which shrink the effective target size) MUST be
overridden in the shared theme rather than accepted. On any platform where a
mouse and keyboard are available (web, desktop, or a touch platform with one
attached), screens MUST also support hover feedback, tooltips on icon-only
controls, a visible keyboard focus order, and keyboard activation of primary
actions — touch MUST NOT be assumed as the only input method once a screen
is reachable outside a touch-only platform. Third-party responsive-layout
packages MUST NOT be added without a documented maintenance-status review
per the Security section's dependency-hygiene rule; Flutter's own
`MediaQuery`/`LayoutBuilder` and the shared breakpoint tokens above are the
default and are normally sufficient on their own.

**Localization**: Vietnamese (`vi`) is the primary language and MUST be the
default locale; English (`en`) MUST be fully supported as a secondary
language. All user-facing strings MUST be externalized via Flutter's
localization mechanism (ARB files + `flutter gen-l10n`, or an equivalent
i18n package) — hardcoded UI strings in widgets are prohibited. Every string
added for a new feature MUST ship with both `vi` and `en` translations in
the same pull request; `vi` MUST NOT lag behind `en`. Currency MUST default
to VND with Vietnamese number-grouping/decimal conventions and MUST switch
correctly for `en` locale users. Date, time, and number formatting MUST use
locale-aware APIs (`intl` package) rather than manual formatting, and layouts
MUST accommodate Vietnamese diacritics and text-length variance without
truncation or overflow. A locale switch MUST be reflected immediately across
the whole app without requiring a restart.

**Rationale**: Inconsistent UI erodes trust in a finance app faster than in
most other app categories, since users are visually cross-checking numbers
across screens; a single design system and formatting utility eliminate an
entire class of "why do these two screens show different totals" bugs.
Vietnamese-first localization reflects the primary user base; treating `en`
as a true second-class-supported (not merely present) language keeps the
app usable for a broader audience without fragmenting the design system.
The same trust argument extends across window sizes and platforms: a user
who checks a balance on a phone and again in a browser tab must see the
same numbers in a layout that reads as deliberately designed for that
window, not a mobile screen stretched thin or a desktop screen cramped into
a phone-shaped column.

### IV. Performance Requirements
The app MUST sustain 60fps (16ms/frame budget) on supported mid-tier
devices for all scrolling lists and animations; any `build()` method or list
item widget suspected of causing jank MUST be profiled with Flutter
DevTools before merge. Cold start MUST be under 2 seconds and time-to-
interactive on the primary dashboard MUST be under 1 second on supported
devices. Lists of transactions/accounts MUST use lazy/virtualized rendering
(`ListView.builder`/`Slivers`) — building full lists eagerly is prohibited.
Expensive work (parsing statements, recalculating aggregates, sync) MUST run
off the UI isolate for payloads above a trivial size, and MUST NOT block
user interaction. State management MUST minimize rebuild scope: widgets
MUST only rebuild in response to state they actually depend on (scoped
selectors/`Consumer` boundaries), not whole-tree rebuilds on unrelated state
changes. Persisted local data access (Drift/SQLite) MUST be indexed for the
query patterns the app actually uses, and MUST NOT run on the UI thread.
These budgets apply on every supported platform — including Web and Desktop
once targeted — measured against that platform's own realistic baseline (a
mid-tier mobile device, an evergreen desktop browser); a platform MUST NOT
silently ship with a materially worse budget just because it was added
later.

**Rationale**: A finance app is opened frequently for quick balance checks;
perceived slowness or jank directly damages the "is my money safe here"
impression users form, independent of actual data correctness.

## Recommended Architecture (Large Flutter Projects)

The project MUST be organized using **Clean Architecture layering combined
with feature-first modules** to keep the codebase navigable and testable as
it scales. "Clean Architecture" here means the dependency rule below
(dependencies point inward, `domain/` depends on nothing); "feature-first"
means that rule is applied independently inside each feature directory
rather than once globally across the whole app:

- **Layering** (each layer depends only on the layer(s) below it):
  - `presentation/` — widgets, screens, and state-management glue
    (e.g. Riverpod/Bloc). Contains no business logic, only orchestration and
    rendering.
  - `domain/` — pure Dart: entities, use cases/interactors, and repository
    *interfaces*. Has zero dependency on Flutter or any specific package
    (no `flutter/material.dart` imports).
  - `data/` — repository *implementations*, data sources (remote API,
    local database, secure storage), and DTO ↔ entity mappers.
- **Feature-first module layout**: code is grouped by feature
  (`features/transactions/`, `features/budgets/`, `features/accounts/`),
  and each feature directory internally follows the presentation/domain/data
  layering above. Cross-feature shared code lives entirely under `core/`.
  Features MUST NOT import another feature's internals directly — only
  through its public API (domain interfaces) or `core/`.
- **`core/` contents**: something belongs in `core/` only if it is used by
  two or more features; single-feature code stays inside that feature's own
  directory. `core/` MUST NOT contain feature-specific business logic —
  only shared infrastructure and framework-agnostic utilities:
  - `theme/` — `ThemeData`, color tokens, typography, spacing constants, and
    adaptive layout tokens (window-size-class breakpoints, content
    max-widths — Principle III)
  - `l10n/` — ARB source files (`app_vi.arb` primary, `app_en.arb`
    secondary) and generated `AppLocalizations`; features MUST consume
    strings only through the generated class, never feature-local string
    constants
  - `router/` — route configuration, route names, navigation guards
  - `di/` — dependency-injection setup (Riverpod provider scope /
    `get_it` registration root)
  - `network/` — HTTP client, interceptors, Supabase client wrapper
  - `database/` — Drift `AppDatabase`, shared tables, migrations
  - `sync/` — outbox worker, connectivity listener, retry/backoff policy
    (see Offline-First Data & Sync)
  - `storage/` — secure storage (tokens/secrets), key-value prefs wrapper
  - `formatting/` — locale-aware currency, date, and number formatters
  - `error/` — shared `Failure`/`Exception` types, error mapper
  - `widgets/` — shared presentational widgets (buttons, cards, empty/
    error/loading states)
  - `utils/` — small pure helpers (validators, extensions); if a helper
    here grows beyond one responsibility, it MUST be promoted to its own
    named subdirectory instead of accreting in `utils/`
  - `constants/` — app-wide constants (env keys, feature flags, limits)
- **Dependency Injection**: dependencies (repositories, services, clients)
  MUST be provided via a DI mechanism (e.g. Riverpod providers or
  `get_it` + injectable) rather than constructed inline inside widgets, so
  they can be swapped for fakes/mocks in tests.
- **State management**: the project MUST standardize on one state-management
  approach (e.g. Riverpod or Bloc/Cubit) for all features — mixing multiple
  competing approaches across features is prohibited without an ADR
  justifying the exception.
- **Suggested top-level layout**:
  ```text
  lib/
  ├── core/
  │   ├── theme/
  │   ├── l10n/           # app_vi.arb (primary), app_en.arb (secondary), generated l10n
  │   ├── router/
  │   ├── di/
  │   ├── network/        # http client + Supabase client wrapper
  │   ├── database/       # Drift AppDatabase, migrations, sync_outbox schema
  │   ├── sync/           # outbox worker, connectivity, retry/backoff
  │   ├── storage/        # secure storage, key-value prefs
  │   ├── formatting/     # currency, date, number formatters
  │   ├── error/          # Failure/Exception types, error mapper
  │   ├── widgets/        # shared dumb widgets
  │   ├── utils/
  │   └── constants/
  ├── features/
  │   ├── transactions/
  │   │   ├── presentation/
  │   │   ├── domain/
  │   │   └── data/       # Drift DAOs + Supabase queries, mappers, repository impl
  │   ├── budgets/
  │   └── accounts/
  └── main.dart
  test/
  ├── unit/           # mirrors lib/ domain + data layers
  ├── widget/         # mirrors lib/ presentation layer
  └── integration/    # end-to-end user flows
  ```
- **Platform-specific/native code** and third-party plugin wrappers MUST be
  isolated behind an abstraction in `core/` or the owning feature's `data/`
  layer, so platform channels can be faked in tests.

This structure exists to keep Principles I–IV enforceable at scale: pure
`domain/` code is what makes 80% domain coverage realistic, and feature
isolation is what keeps code review scoped and reviewable.

## Offline-First Data & Sync (Local DB + Supabase)

The app MUST work fully offline and treat the local database as the
immediate source of truth for reads/writes, syncing to Supabase in the
background:

- **Local database**: **Drift (SQLite)** MUST be used as the local
  persistence layer for all relational financial data (transactions,
  accounts, budgets, categories). Drift is chosen over key-value stores
  (e.g. Hive) because it provides ACID transactions, typed schema with
  versioned migrations, and reactive `watch()` queries — required to keep
  balance/aggregate calculations correct and testable per Principles I and
  II. A key-value store MAY still be used, but only for non-relational,
  non-financial data (e.g. app settings, UI preferences, cached tokens),
  never as the source of truth for money data.
- **Sync architecture**: changes MUST follow an **outbox/queue pattern**:
  every local write (insert/update/delete) is committed to its Drift table
  AND appended to a local `sync_outbox` table in the same transaction. A
  background sync worker (off the UI isolate, per Principle IV) drains the
  outbox to Supabase when connectivity is available, with retry and
  exponential backoff on failure. The UI MUST NEVER block on network sync —
  all reads/writes against the local DB MUST succeed immediately regardless
  of connectivity.
- **Pulling remote changes**: the app MUST use Supabase Realtime
  (Postgres change feed) to receive remote updates and upsert them into
  Drift, rather than polling. Each syncable row MUST carry `updated_at` and
  a `deleted_at` (soft-delete/tombstone) column.
- **Conflict resolution**: default strategy is **last-write-wins by
  `updated_at`** for user-editable fields (e.g. transaction notes,
  category). Account/transaction balances MUST be treated as
  **server-authoritative**: the client MUST NOT trust a locally computed
  balance as final — it MUST reconcile against a balance recomputed from
  the transaction log on the Supabase side (e.g. via a Postgres
  function/view), and surface a reconciliation conflict to the user rather
  than silently overwriting local data if the two diverge unexpectedly.
- **Data layer boundary**: Supabase DTOs (`data/` layer) MUST NOT leak into
  `domain/` entities. A dedicated mapper converts Supabase rows ↔ Drift rows
  ↔ domain entities, so the local schema and remote schema are free to
  diverge (e.g. added sync metadata columns) without changing domain code.
- **Testability**: the sync worker and conflict-resolution logic MUST be
  unit-testable without a live Supabase connection — the Supabase client
  MUST be wrapped behind a repository interface in `domain/` so it can be
  faked in tests, per the Testing Standards principle.

**Rationale**: Financial data must never be lost or silently corrupted when
offline, which rules out treating sync as an afterthought or trusting
last-write-wins for balances. Drift's ACID guarantees and typed queries
make correctness and testing tractable in a way a key-value store cannot;
the outbox pattern makes sync auditable and debuggable (a stuck/failed sync
is a visible row in a queue, not a silent failure) and keeps the UI
responsive offline, which Principle IV requires regardless of network
state.

## Multi-Platform Support

The app's supported platform set is **Android, iOS, and Web**; native
**Desktop** (Windows/macOS/Linux) MAY be added later without an architecture
change, per the window-size-driven adaptive design rules in Principle III:

- **Web is a fully supported target, not a stretch goal**: a screen or data
  flow that fails on Web (blank data, an unhandled exception, a broken auth
  redirect) is a Principle I defect, not an acceptable platform gap. Every
  new feature's plan MUST state whether it was verified on Web alongside
  mobile.
- **Local database on Web**: Drift MUST be opened with `DriftWebOptions`
  supplying a same-origin `sqlite3.wasm` and `drift_worker.js` (served with
  the `application/wasm` content type), per the Offline-First Data & Sync
  section's local-database mandate — Web is not exempt from "local DB as
  source of truth" just because it lacks a native filesystem.
- **Capability detection over platform assumption**: where a platform
  genuinely lacks a capability another platform has (e.g. no biometric
  hardware/API on Web), the app MUST detect that capability at runtime and
  fall back to another still-secure option already required elsewhere in
  this constitution (e.g. the PIN fallback required by the Security
  section's app-level-lock rule) — it MUST NOT silently drop the
  requirement for that platform.
- **Platform-specific integration points** (OAuth/password-reset redirect
  URLs, deep-link schemes, secure-storage backends) MUST be resolved behind
  the `core/auth/` and `core/storage/` abstractions per the Recommended
  Architecture section's platform-isolation rule — never hardcoded to a
  single platform's scheme or URL.
- **Desktop native builds are opt-in, deferred scope**: adding a Windows/
  macOS/Linux target (platform folders, packaging, code signing) is not
  required until a feature plan explicitly scopes it; until then, the Web
  build installed as a PWA is an acceptable desktop-usage path. When a
  native desktop target is added, its window MUST enforce a minimum size
  consistent with the compact breakpoint (Principle III) so the app never
  renders below its smallest supported layout.
- **App identity on Web** MUST reflect the shipped product, not framework
  scaffolding defaults: page title, `manifest.json` name/icons/theme color,
  and the URL strategy (path-based, no `#`) MUST match the app the user
  actually sees on other platforms.

**Rationale**: An audit behind this amendment found the local database
silently failed to open on Web at all (`driftDatabase` was called without
the `web:` parameter Drift requires there), which would make any "Web
support" claim false until fixed — this section exists so a platform is
never declared supported by intent alone, only by a verifiable checklist.
Keeping layout decisions window-size-driven (Principle III) rather than
platform-driven is what lets Desktop be added later as a packaging exercise
rather than a rewrite.

## Security

Financial and personal data require security to be a first-class,
non-optional concern, not an afterthought bolted on before release:

- **Supabase Row Level Security (RLS) MUST be enabled on every table**
  containing user data; access MUST be scoped so a user can only read/write
  their own rows. A table without an RLS policy MUST NOT be deployed.
- **Secrets and tokens** (Supabase auth tokens, API keys) MUST be stored via
  platform secure storage (`core/storage/`, e.g. Keychain/Keystore-backed
  packages) — never in `SharedPreferences`, plain files, or Hive without
  encryption.
- **Transport security**: all network calls (Supabase REST/Realtime) MUST
  use TLS; certificate/domain pinning SHOULD be evaluated for the Supabase
  endpoint given the sensitivity of financial data.
- **Logging discipline**: raw financial data (transaction amounts,
  balances, account numbers) and auth tokens MUST NOT be written to logs,
  crash reports, or analytics events, even in debug builds committed to the
  repository. Structured logs MAY reference entity IDs, never their
  financial values.
- **Local device security**: the local Drift database SHOULD be encrypted
  at rest (e.g. via SQLCipher-backed Drift) on platforms where the OS does
  not already provide full-disk encryption guarantees equivalent to it, and
  the app MUST support an app-level lock (biometric/PIN) gating access to
  financial data after launch or resume from background. On a platform
  where biometric hardware/APIs are unavailable (e.g. Web), the PIN path
  MUST still be offered — the app MUST NOT leave that platform with no
  app-level lock at all (Multi-Platform Support's capability-detection
  rule).
- **Dependency hygiene**: third-party packages MUST be reviewed before
  addition (maintenance status, license, permissions requested) and kept
  up to date; `flutter pub outdated` MUST be checked as part of routine
  maintenance, not only when a vulnerability is reported.

**Rationale**: A finance app is a high-value target — leaked tokens or
missing RLS policies expose every user's transactions, not just one row.
These requirements are cheap to satisfy from day one and expensive to retrofit
once features assume an insecure default.

## Development Workflow

- All new work happens on a feature branch; direct commits to `main` are
  prohibited.
- Pull requests MUST pass CI (analyze, format check, full test suite) before
  merge.
- `flutter format` (or `dart format`) MUST be applied to all Dart files;
  unformatted code MUST NOT be merged.
- Every PR touching financial calculation logic MUST include or update unit
  tests demonstrating the specific scenario changed, per Principle II.
- Breaking changes to shared `core/` utilities REQUIRE explicit call-out in
  the PR description, since they affect every feature: theming/formatting/
  breakpoint changes per Principle III (User Experience Consistency &
  Adaptive Design), DI/database/sync changes per the Recommended
  Architecture and Offline-First Data & Sync sections, and any change to
  platform-capability detection or integration points per Multi-Platform
  Support.

## Governance

This constitution supersedes all other project practices and ad hoc
conventions. Amendments require: (1) a documented rationale for the change,
(2) an update to this file via the `/speckit-constitution` workflow so the
Sync Impact Report and version bump are recorded, and (3) propagation of any
resulting changes to `plan-template.md`, `spec-template.md`, and
`tasks-template.md` where applicable.

All pull requests and code reviews MUST verify compliance with these
principles; the "Constitution Check" gate in `plan-template.md` is
authoritative for feature planning. Any deviation MUST be justified in the
plan's Complexity Tracking table — unjustified complexity is grounds for
rejecting a plan. Amendment versioning follows semantic versioning: MAJOR
for backward-incompatible governance/principle removals or redefinitions,
MINOR for new principles or materially expanded guidance, PATCH for wording
clarifications and non-semantic refinements.

**Version**: 1.5.0 | **Ratified**: 2026-07-24 | **Last Amended**: 2026-09-25
