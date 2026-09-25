# Internal Contract: Web Platform Enablement

## Purpose

Define the internal contracts this feature introduces or changes. This
feature has no public HTTP API of its own; "Gateway Contracts" below
covers its one real external dependency (Supabase's redirect handling).

## Gateway Contracts

### Supabase `resetPasswordForEmail` (existing call, new `redirectTo` value)

- **Input** (unchanged): `email` (unchanged).
- **New behavior**: `redirectTo` is now `kIsWeb ? AppEnvironment.
  webPasswordResetRedirectUrl : 'com.finance.finance://reset-callback'`
  (research.md Decision 5), via the pure `resolvePasswordResetRedirectUrl`
  helper (data-model.md).
- **External dependency this contract assumes, not controls**: the Web
  URL must be present in Supabase's own Dashboard allowed-redirect list
  before a real reset email's link will work end-to-end — this is the
  user's own action item, outside this codebase (spec.md Assumptions,
  unchanged from `/speckit-specify`).
- **Failure mode** (unchanged): identical to today — a Supabase API
  error surfaces to the caller exactly as it does now; this feature does
  not add or remove error handling here, only changes which string is
  passed as `redirectTo`.

### Drift `driftDatabase()` (existing call, new `web:` parameter)

- **Input**: `name: 'finance'` (unchanged), **+ new** `web:
  DriftWebOptions(sqlite3Wasm: Uri.parse('sqlite3.wasm'), driftWorker:
  Uri.parse('drift_worker.js'))` (research.md Decisions 1–2).
- **Output**: unchanged type (`QueryExecutor`) and unchanged native-
  platform behavior (`web` is "ignored... on native platforms" per the
  installed `drift_flutter` package's own doc comment) — mobile's
  executor/path/migration behavior is byte-for-byte identical to today.
- **New Web behavior**: no longer throws `ArgumentError` synchronously;
  instead lazily opens via `WasmDatabase.open(...)` on first query,
  self-selecting OPFS or IndexedDB (research.md Decision 1).
- **Failure mode**: a rejected `Future` from the lazy connection, forced
  to resolve (and, on failure, caught) by the new `kIsWeb`-only startup
  warm-up query — see the Startup Contract below. This is new: today
  there is no "failure mode" to speak of, because Web never reaches this
  point at all (it throws before ever returning a connection).

## Presentation Contracts

### `_StartupErrorApp` (existing widget, parameterized)

- **Input** (new): `required _StartupFailureReason reason`
  (data-model.md) — was previously a zero-parameter `const` widget with a
  single, hardcoded Supabase-specific copy pair.
- **Output**: identical visual structure to today (centered icon + title
  + message, `Theme.of(context).textTheme.titleLarge` for the title) —
  only the two localized strings shown vary by `reason`.
- **Callers**: `initSupabase()`'s existing catch block now passes
  `reason: _StartupFailureReason.supabaseConfig` (behavior-preserving —
  same two ARB keys as today); the new Web-only database warm-up catch
  block passes `reason: _StartupFailureReason.webStorage` (new ARB keys —
  data-model.md).

### Startup Contract (`lib/main.dart`, `main()`, new Web-only step)

- **Sequence** (research.md Decision 9): `WidgetsFlutterBinding.
  ensureInitialized()` → `usePathUrlStrategy()` (research.md Decision 6,
  all platforms) → `initSupabase()` (existing, unchanged try/catch) →
  **new**: if `kIsWeb`, create a `ProviderContainer`, `await` a warm-up
  query against `container.read(appDatabaseProvider)` inside its own
  try/catch → on failure, `runApp(_StartupErrorApp(reason: .webStorage))`
  and return; on success (or on non-Web platforms, skipped entirely) →
  existing preference-loading step, unchanged → `runApp(...)`, now via
  `UncontrolledProviderScope(container: container, child: const
  FinanceApp())` on Web (reusing the warmed-up container) or the existing
  plain `ProviderScope(...)` on other platforms (no container to reuse,
  since the warm-up step is skipped there — FR-012).
- **Guarantee**: by the time `FinanceApp`'s first real screen builds on
  Web, `appDatabaseProvider`'s database has already been successfully
  opened and migrated at least once, or the user is already looking at
  `_StartupErrorApp` instead — no screen can reach a state where its
  first database query is the *first* time the Web connection is
  attempted (FR-014, SC-001's "zero unhandled data-loading errors").

## Error Contract

**One new failure path** (the Startup Contract above); every other error
contract in the app (Supabase auth errors, existing repository failure
mappers) is unchanged by this feature.

## Navigation Contract

**No new route or path.** The existing five `StatefulShellRoute` branches
are unchanged. What changes is how the *browser* represents the
already-existing paths in its address bar (hash fragment → real path,
research.md Decision 6) — a URL-strategy change, not a routing-table
change. `web/manifest.json`'s `start_url` (`"."`, relative to wherever
`index.html` is served from) is unaffected by the path-strategy change and
is left as-is.
