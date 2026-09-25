# Feature Specification: Secure Storage Risk Decision & Routing Cleanup

**Feature Branch**: `20260925-051953-secure-storage-routing-cleanup`
<!-- Logical feature identifier only (matches this spec directory's name),
     per this repo's established convention. Actual git work stays on the
     session-designated `claude/sweet-fermi-yd1qj8`. -->

**Created**: 2026-09-25

**Status**: Implemented (User Story 1 complete; User Story 2 complete for
all 7 of 7 original call sites, including Tier C)

**Input**: User description: "Two small, independent follow-ups explicitly
deferred from `web-platform-enablement`'s Out-of-Scope section, combined
into one spec (session budget is limited) but kept as two separate,
independently-testable user stories. P1: a risk-acceptance decision for
`flutter_secure_storage`'s experimental Web backend (WebCrypto +
localStorage, needs HSTS) — primarily a documented decision, not
necessarily new code. P2: convert the remaining `Navigator.push` call
sites (spending_screen.dart, overview_screen.dart, account_screen.dart) to
real go_router routes, preserving today's exact UI — no redesign — so
these screens finally get real URLs/back-button support on Web."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An explicit, reviewed decision on Web session-token storage risk (Priority: P1)

As the project's maintainer, I want a clear, written decision on whether
storing the Supabase session token via `flutter_secure_storage`'s
experimental Web backend is acceptable, instead of an unresolved question
sitting silently in a spec's "Out of Scope" section, so that this known
risk is either formally accepted with reasoning or mitigated — not just
forgotten.

**Why this priority**: Smallest, most certain to finish; a documented
decision has zero implementation risk and directly closes a real,
already-identified gap from the previous feature.

**Independent Test**: Read the constitution's Security section and this
spec — confirm a specific, reasoned decision exists (not a vague "TODO"),
naming the accepted risk, why it's acceptable for this app's threat model,
and what (if anything) is required before Web is treated as production-
ready for real user sessions.

**Acceptance Scenarios**:

1. **Given** the constitution's Security section, **When** it is read,
   **Then** it states explicitly whether the Web session-token storage
   risk is accepted or requires hardening, with reasoning tied to this
   app's actual data (a session token, not raw financial figures).
2. **Given** the decision is "accept with a condition" (e.g. HSTS at the
   eventual host), **When** the condition is not yet met (no Web host is
   chosen yet, per `web-platform-enablement`'s own Assumptions), **Then**
   that dependency is stated explicitly, not silently assumed satisfied.

---

### User Story 2 - Web screens reachable by URL instead of only by push (Priority: P2)

As someone using the app on Web, I want the screens currently opened via
an imperative push (categories/details reached from Thu chi, Tổng quan,
and Hồ sơ) to have their own address and respond to the browser's back
button, the same way the app's five main tabs already do, so that Web
navigation feels consistent instead of some screens supporting
bookmarking/back and others silently not.

**Why this priority**: Larger than User Story 1, but each converted call
site is independently valuable and independently stoppable — a partial
conversion is a safe, non-broken intermediate state, not a shipped
half-feature.

**Independent Test**: On a Web build, open a screen previously reached via
`Navigator.push` (e.g. a Thu chi category picker) and confirm the address
bar shows a real path; press the browser's back button and confirm it
returns to the previous screen; confirm the screen's own appearance and
behavior are pixel-identical to before this feature — no redesign.

**Acceptance Scenarios**:

1. **Given** a screen previously reached via `Navigator.push`, **When** it
   is opened, **Then** the browser's address bar shows a distinct,
   real path (not the same URL as the screen it was opened from).
2. **Given** such a screen is open, **When** the browser's back button (or
   the in-app back affordance) is used, **Then** it returns to the
   previous screen, exactly as `Navigator.push`'s pop already does today.
3. **Given** any converted screen, **When** it is compared to its
   pre-feature appearance and behavior, **Then** there is no visible
   difference — this feature changes only how the screen is reached, not
   what it looks like or does once open.
4. **Given** the full conversion is not entirely finished (e.g. session
   budget runs out after converting some but not all call sites), **When**
   the app is used, **Then** every screen still works correctly — the
   unconverted ones exactly as before (still pushed), the converted ones
   via their new route — with no broken or half-migrated screen.

---

### Edge Cases

- What happens to a route converted from a push site if it required data
  only available from its caller's local state/closures (e.g. an item
  the caller has already loaded)? The new route MUST still receive
  equivalent data (via path parameters, query parameters, or router
  `extra`), not silently lose it.
- What happens when a not-yet-converted screen is used at the same time
  as an already-converted one? Both MUST continue to work exactly as
  today — this feature does not require an all-or-nothing cutover.
- What happens if the Web host chosen later (still undecided, per
  `web-platform-enablement`'s Assumptions) never enables HSTS? User Story
  1's decision MUST already state what that means for the accepted risk,
  rather than leaving it to be discovered later.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The constitution's Security section MUST contain an
  explicit statement of the Web session-token storage risk and this
  project's decision about it (accept, or harden), including the specific
  reasoning tied to what is actually stored (a session token) and what is
  not (raw financial data, which is unaffected by this decision).
- **FR-002**: If the decision is to accept the risk conditionally (e.g.
  contingent on HSTS at the eventual host), that condition MUST be
  recorded as an explicit dependency, cross-referenced to
  `web-platform-enablement`'s existing "Web hosting target is undecided"
  Assumption rather than duplicated or contradicted.
- **FR-003**: Every screen converted from `Navigator.push` to a route
  MUST remain reachable, functionally and visually unchanged, from every
  existing entry point that opens it today.
- **FR-004**: Every converted screen MUST be addressable by its own
  distinct path and MUST support the browser back button / standard pop
  behavior equivalently to today's `Navigator.push`.
- **FR-005**: This feature MUST NOT change any screen's layout, content,
  or visual design — only the mechanism used to reach it.
- **FR-006**: Data currently passed into a pushed screen via constructor
  parameters MUST continue to reach the equivalent routed screen
  correctly (no silently-dropped parameter).
- **FR-007**: The full existing automated test suite MUST continue to
  pass after this feature; any test that specifically asserted
  push-based navigation for a converted screen MUST be updated to assert
  the equivalent route-based behavior, not deleted.
- **FR-008**: User Story 2 MUST be implementable and shippable as a
  partial conversion (some call sites converted, some not) without
  breaking any screen — no functional requirement in this feature depends
  on all call sites being converted together.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The constitution contains a specific, named decision on Web
  session-token storage risk — verifiable by reading the Security section
  and finding no open question left as "TODO" or unaddressed.
- **SC-002**: 100% of the `Navigator.push` call sites converted in this
  feature produce a distinct, bookmarkable path on Web and respond
  correctly to the browser back button.
- **SC-003**: Every screen touched by this feature is visually and
  behaviorally identical to its pre-feature version — verified by
  construction (no screen's own rendering code is touched, only the
  navigation trigger that opens it) and cross-checked by that screen's
  existing test suite passing unchanged.
- **SC-004**: The existing automated test suite (428 tests as of this
  feature's start) passes in full after this feature.

## Assumptions

- This feature does not decide which screens eventually get a list-detail
  redesign (`adaptive-layout-foundation/spec.md` §B) — it only gives
  currently-pushed screens a real URL, using their current, unchanged
  layout. A future redesign is free to change the route shape again.
- User Story 2 may ship partially complete (some call sites converted,
  others not) if session budget runs out — this is an accepted, planned
  outcome (FR-008), not a failure state, and is recorded as such rather
  than silently left inconsistent.
- User Story 1's decision does not require implementing HSTS itself
  (that's a hosting-level action, already tracked as undecided) — it only
  requires the decision and its conditions to be explicitly written down.
- No change to what data `SecureLocalStorage` stores (still only the
  serialized Supabase session, per `lib/core/storage/secure_local_storage.dart`)
  — this feature is a risk decision, not a storage-mechanism change,
  unless User Story 1's own conclusion determines otherwise.

## Out of Scope & Follow-Up Work

- **Native Desktop, PIN-entry app lock**: unchanged, still deferred per
  `web-platform-enablement`'s own Out-of-Scope items — not touched here.
- **Per-screen adaptive/list-detail redesign** (`adaptive-layout-foundation`
  §B): explicitly not this feature's job — User Story 2 preserves each
  screen's current layout exactly; the redesign remains its own future
  work, to be done together with whatever route shape it actually needs
  (which may differ from this feature's straightforward 1:1 conversion).
- **HSTS/hosting configuration itself**: outside this codebase, same
  external dependency already recorded in `web-platform-enablement`'s
  Assumptions (Web host still undecided).
