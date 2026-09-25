# Phase 0 Research: Secure Storage Risk Decision & Routing Cleanup

Kept intentionally leaner than prior features' research.md, per this
session's stated budget constraint — still evidence-grounded, not
guessed, but without exhaustive alternatives-considered prose where the
decision is clear-cut.

## Decision 1: The secure-storage risk decision itself

**Decision**: **Accept the risk, conditionally.** Record in the
constitution's Security section: Web session-token storage via
`flutter_secure_storage`'s WebCrypto+`localStorage` backend is accepted
for this app's threat model, on the condition that the eventual Web host
enables HSTS (already an open dependency, not newly introduced here).

**Rationale** (confirmed directly against the installed
`flutter_secure_storage-9.2.4` package's own README, not memory): what's
stored is a Supabase session (access+refresh token pair) via
`lib/core/storage/secure_local_storage.dart` — not raw financial data
(transactions/balances live in Drift, already unencrypted-at-rest on
every platform per `web-platform-enablement`'s own Assumptions). A
stolen session is time-limited and revocable (the app already has a
global-sign-out flow, `AuthRepository.confirmPasswordReset`), unlike a
permanent data leak. The package's README states the specific attack this
guards against is a "javascript hijack" over an unencrypted transport —
exactly what HSTS closes. Flutter Web's compiled output (dart2js/
dart2wasm, no default `innerHTML`/`eval`-style templating) has a smaller
baseline same-origin-script-injection surface than a typical hand-written
JS SPA, which further narrows the realistic exploitation path. Building a
custom alternative (e.g. a server-side session/cookie model) would be a
materially larger architecture change than this risk warrants, and no
better-vetted Flutter-Web-compatible alternative exists in the ecosystem
today — WebCrypto+localStorage is close to the current state of the art
for browser-based secret storage without a backend session store.

## Decision 2: Navigator.push → go_router route shape

**Decision**: Nest new routes as children of the relevant branch's
existing `GoRoute` (e.g. `GoRoute(path: '/spending', ..., routes:
[GoRoute(path: 'income', ...)])`), not as top-level sibling routes.

**Rationale**: `StatefulShellRoute.indexedStack` gives each branch its own
nested `Navigator`; today's `Navigator.of(context).push(...)` calls
resolve to that same nested `Navigator` (confirmed by re-reading
`app_router.dart`'s route tree — no branch has any child route today, so
this hasn't been exercised yet, but it's exactly how go_router documents
`StatefulShellRoute` child routes working). That nested Navigator sits
*inside* `_AppShell`'s chrome (the bottom bar/rail wraps
`navigationShell`, not the other way around), so today's pushed screens
already render with the shell chrome still present around them — a
top-level sibling route would instead remove that chrome entirely,
visibly changing the screen (violating FR-005). Nesting preserves it.

## Decision 3: Real complexity found in the 7 call sites — three tiers, not one

Re-reading every call site (not just grepping the `Navigator.push` line)
found meaningfully different shapes, which changes this feature's real
task sizing:

- **Tier A — parameterless** (`spending_screen.dart:52,67,79` →
  `IncomeScreen`/`ExpenseScreen`/`TransactionHistoryScreen`;
  `overview_screen.dart:392` "see all" → `TransactionHistoryScreen`
  again, unfiltered): a plain `GoRoute` with a `const` builder, no
  parameter passing. Lowest risk, highest confidence — **do first**.
- **Tier B — parameterized, but with simple string data**
  (`overview_screen.dart:129`'s notification bell, and
  `account_screen.dart`'s shared `_openPlaceholder` helper — actually 3
  logical call sites at lines 152/164/176, not 1, despite `grep` finding
  only one `Navigator.push` textually): all go to the same
  `NotAvailablePlaceholderScreen(icon, title, message)`, but `icon` is an
  `IconData` (not URL-safe) and `title`/`message` are already-resolved
  localized strings (would go stale across a locale switch if baked into
  a URL). Correct shape: a route taking a small `featureKey` query/path
  parameter, with the route builder mapping that key to the right
  icon/l10n getters — not passing the resolved strings/IconData directly.
  **Do second, if budget allows.**
- **Tier C — dynamic Riverpod provider override**
  (`overview_screen.dart:607`'s `_openFilteredHistory`, wrapping
  `TransactionHistoryScreen` in a nested `ProviderScope` overriding
  `selectedTransactionHistoryFilterProvider` with
  `TransactionHistoryFilter.group(accountName)`): the most complex site —
  needs a route that reads `accountName` from a path parameter and
  reconstructs the equivalent provider override inside its own builder
  function. Real, doable, but the highest-effort single site by far.
  **Lowest priority — explicitly optional per spec.md FR-008/Assumptions;
  stop here first if budget is tight, leaving this one site on its
  existing, unchanged `Navigator.push`.**

This tiering is the direct basis for this feature's task and priority
ordering — spec.md's User Story 2 already anticipates partial completion
(FR-008), and this is exactly where the natural stopping points fall.

## Decision 4: Testing approach

Existing tests that assert push-based navigation for a converted screen
(if any exist) need updating to assert route-based navigation instead —
go_router provides `GoRouterState`/`context.push` equivalents that are
directly testable in a widget test via a real `GoRouter` in the test
harness (already the pattern `test/widget/features/account/
reset_password_screen_test.dart` uses — a real `GoRouter` with test
routes, not a mock). No new testing *mechanism* is needed, only new test
cases per converted route, following that existing pattern.
