<!--
Sync Impact Report
Version change: 1.3.0 → 1.4.0 (MINOR: added Security section — new section, no
  principle redefined or removed)
Modified principles: none
Added sections:
  - Security: Supabase RLS mandatory per table, secure storage for secrets/tokens,
    TLS/pinning, logging discipline (no raw financial data/tokens in logs), local DB
    encryption at rest + app-level lock, dependency hygiene review
Modified sections:
  - Recommended Architecture (Large Flutter Projects) → explicitly named the pattern
    "Clean Architecture layering combined with feature-first modules" (was described
    without a name); trimmed a duplicated closing rationale sentence
  - Development Workflow → fixed a mis-attributed reference (breaking core/ utility
    changes cited only Principle III; DI/database/sync changes now correctly point to
    the Recommended Architecture / Offline-First sections instead)
Removed sections: none
Templates requiring updates:
  - .specify/templates/plan-template.md: ✅ compatible (Constitution Check gate can
    reference Security section per-feature; no edits needed)
  - .specify/templates/spec-template.md: ✅ compatible (no constitution-specific
    references)
  - .specify/templates/tasks-template.md: ✅ compatible (Security hardening already
    listed as a Polish-phase task category)
  - .specify/templates/commands/*.md: not present in this project
Follow-up TODOs: none
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
(charts, balance summaries).

**Rationale**: Correctness of money math is non-negotiable — an unnoticed
rounding or sign error erodes user trust immediately. High coverage in the
domain layer is achievable precisely because Principle I keeps that logic
separate from Flutter widgets.

### III. User Experience Consistency
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
  - `theme/` — `ThemeData`, color tokens, typography, spacing constants
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
  financial data after launch or resume from background.
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
  the PR description, since they affect every feature: theming/formatting
  changes per Principle III (User Experience Consistency), DI/database/sync
  changes per the Recommended Architecture and Offline-First Data & Sync
  sections.

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

**Version**: 1.4.0 | **Ratified**: 2026-07-24 | **Last Amended**: 2026-07-24
