# Implementation Plan: Secure Storage Risk Decision & Routing Cleanup

**Branch**: `20260925-051953-secure-storage-routing-cleanup` | **Date**: 2026-09-25 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from
`specs/20260925-051953-secure-storage-routing-cleanup/spec.md`

**Note**: Kept leaner than prior features' plans (no separate data-model.md/
contracts/quickstart.md) per this session's stated budget constraint —
this feature introduces no new domain entity or external contract, so
those files would be near-empty overhead. Verification notes live in
tasks.md instead of a separate quickstart.md.

**Outcome** (this plan was re-read post-implementation — synced rather
than regenerated, since nothing here became inaccurate, only some
forward-looking phrasing needed updating): P1 shipped as planned. P2
shipped in full — all three tiers, all 7 of 7 original call sites
converted (Tier C landed in a follow-up session; see tasks.md T013/T014
for exact shape and verification).

## Summary

Two independent user stories, one spec: (P1) an explicit, written
risk-acceptance decision for `flutter_secure_storage`'s experimental Web
backend, recorded in the constitution — accept, conditional on HSTS at
the eventual host (research.md Decision 1); no application code change.
(P2) convert `Navigator.push` call sites to nested `go_router` routes
(research.md Decision 2), preserving exact current appearance/behavior —
staged in three tiers by real complexity discovered during research
(Decision 3), with FR-008 explicitly allowing the feature to stop after
any tier if budget runs out.

## Technical Context

**Language/Version**: Dart 3.11.0 / Flutter 3.41.0 (unchanged).

**Primary Dependencies**: `go_router` (existing, ^14.6.2 — no new
package; only new `GoRoute` entries nested under existing branches),
`flutter_riverpod` (existing — Tier C, not attempted, would have reused
the existing `ProviderScope`-override pattern already used at that call
site, just relocated into a route builder function; the call site itself
is untouched, still using that pattern directly).

**Storage**: No change to what `SecureLocalStorage` stores or how — P1 is
a documented decision, not a mechanism change (spec.md Assumptions).

**Testing**: `flutter analyze`, `dart format --output=none
--set-exit-if-changed lib test`, `flutter test` (428 tests at this
feature's start, per spec.md SC-004). New/updated widget tests per
converted route, following the existing real-`GoRouter`-in-test-harness
pattern already used in `reset_password_screen_test.dart` (research.md
Decision 4).

**Target Platform**: Android, iOS, Web — unchanged platform set. P2's
benefit (real URLs/back-button) is Web-specific, but the route
conversion itself changes navigation mechanics identically on every
platform (mobile's `Navigator`-backed push-equivalent via go_router
behaves the same as today there too — no behavior change to verify
separately per platform beyond what the shared test suite covers).

**Constraints**: No layout/visual change anywhere (FR-005); no new route
may drop the shell chrome (research.md Decision 2); Tier C is optional
per FR-008 — the feature is complete and shippable after Tier A alone.

**Scale/Scope** (final): 4 new nested `GoRoute`s shipped (Tier A: income,
expense, 2×transaction-history — the two `TransactionHistoryScreen`
pushes share one route builder each, nested under its own branch, since
go_router doesn't support one route under two different parents); 2 new
routes + a small key→copy lookup shipped (Tier B, covering 4 logical call
sites — `AccountPlaceholderFeature` for the 3 account rows, plus one
dedicated route for the overview notification bell); 1 parameterized
`group/:accountName` route shipped (Tier C, nested under `/overview`'s
`history` route, rebuilding the same `ProviderScope` override the
original call site used); 1 constitution amendment shipped (P1, no code).
Call sites converted: 7 of 7, across 3 existing files.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

- **Principle I — Code Quality: PASS.** No new mixed-responsibility
  widget; route builder functions follow the exact existing
  `Widget xRoute(BuildContext, GoRouterState) => ...` convention already
  used throughout `*_routes.dart` files.
- **Principle II — Testing Standards: PASS.** Every converted route gets
  an updated/new test using this repo's own established real-`GoRouter`
  test pattern (research.md Decision 4); P1 needs no test (a
  documentation change).
- **Principle III — User Experience Consistency & Adaptive Design: PASS —
  N/A change, explicitly protected.** FR-005 requires zero visual/layout
  change; research.md Decision 2's nested-route shape is specifically
  chosen to preserve today's shell-chrome behavior exactly.
- **Principle IV — Performance: PASS.** No new async work, no new list,
  no new query — a routing-mechanism swap only.
- **Recommended Architecture: PASS.** Route definitions stay in each
  feature's existing `*_routes.dart` file, matching the constitution's
  `core/router/` + per-feature-routes convention already established.
- **Multi-Platform Support: PASS — directly closes part of the
  `web-platform-enablement`'s own follow-up backlog** (that spec's Out of
  Scope §A.7 named exactly these call sites as needing this conversion).
- **Security: PASS — this feature's P1 *is* the required action here.**
  The constitution's Security section currently has no statement on Web
  session-token storage risk; this feature adds one (research.md Decision
  1), turning a silent gap into an explicit, reviewed decision — exactly
  what `/speckit-analyze` finding-style scrutiny would otherwise flag as
  missing.
- **Development Workflow: PASS (procedural).** Constitution amendment
  (P1) and `core/router`-adjacent changes (P2) both get called out in the
  PR description per the breaking-change bullet.

**Post-design re-check**: PASS. No new package, no new external service.
Tier C (research.md Decision 3) shipped in full — see tasks.md T013/T014.

## Project Structure

### Documentation (this feature)

```text
specs/20260925-051953-secure-storage-routing-cleanup/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── checklists/          # Spec quality checklist
└── tasks.md             # Phase 2 output (/speckit-tasks)
```

### Source Code (repository root)

```text
.specify/memory/constitution.md      # MODIFIED: Security section gains the
                                      # Web session-token storage risk
                                      # decision (P1, research.md Decision 1)

lib/features/expenses/
├── expenses_routes.dart             # MODIFIED: + income/expense/history
│                                     # route builder functions (Tier A);
│                                     # + overviewFilteredHistoryRoute
│                                     # (Tier C)
└── presentation/
    ├── spending_screen.dart         # MODIFIED: 3 pushes -> context.push
    │                                # (Tier A)
    └── overview_screen.dart         # MODIFIED: "see all" push -> context.push
                                      # (Tier A); notification-bell push ->
                                      # context.push (Tier B); filtered-
                                      # history push -> context.push, dead
                                      # _openFilteredHistory method + its
                                      # now-unused imports removed (Tier C)

lib/features/account/
├── account_routes.dart              # MODIFIED: + placeholder route (Tier B)
└── presentation/account_screen.dart # MODIFIED: 3 menu items -> context.push
                                      # (Tier B)

lib/core/router/app_router.dart      # MODIFIED: new routes nested under
                                      # each relevant branch's existing
                                      # GoRoute (research.md Decision 2)

test/widget/features/expenses/       # MODIFIED/NEW: route-based assertions
test/widget/features/account/        # MODIFIED/NEW: route-based assertions
```

**Structure Decision**: No new feature directory. Route definitions stay
in each feature's existing `*_routes.dart` file; `app_router.dart`'s tree
gains nested children, not new top-level branches. All work stays on the
session-designated `claude/sweet-fermi-yd1qj8`, per this session's branch
note.

## Phase 0: Research Summary

See [research.md](./research.md) — 4 decisions: the secure-storage
risk-acceptance decision itself and its reasoning (Decision 1); nested
(not top-level) routes to preserve shell chrome (Decision 2); a 3-tier
complexity breakdown of the 7 call sites, found by reading each site's
actual code rather than trusting the grep-level "7 sites" count alone —
several are parameterless (Tier A, shipped), several share one
parameterized helper needing a small key→copy lookup rather than baking
resolved strings into a URL (Tier B, shipped), and one wraps a dynamic
Riverpod provider override (Tier C, explicitly gated on remaining budget
— not attempted) (Decision 3); and reuse of this repo's own existing
real-`GoRouter` widget-test pattern, no new test infrastructure
(Decision 4).

## Complexity Tracking

No constitution violations. Tier C's conditional/optional status
(Decision 3) is a scope decision already made explicit in spec.md
(FR-008), not smuggled-in complexity.
