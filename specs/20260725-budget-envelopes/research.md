# Research: Budget Envelopes

## 1. Allocation rounding algorithm

**Decision**: For each allocation event, compute in this exact order:
1. `fixed_total = sum(configured amount for each fixed-amount envelope)`.
2. For each percentage envelope: `raw_share = income_entered * percentage` (exact rational/decimal arithmetic, not floating point), then `rounded_share = round_half_up(raw_share)` to the nearest whole VND.
3. `percentage_total = sum(rounded_share for all percentage envelopes)`.
4. `claimed = fixed_total + percentage_total`.
5. `leftover = income_entered - claimed`.
   - If `leftover > 0` and a rounding-remainder receiver is flagged: add `leftover` to that envelope's allocation for this event (per spec FR-007 — this single number already covers both rounding dust and any structural under-allocation gap, since both reduce to "income minus what was actually claimed").
   - If `leftover > 0` and **no** envelope is flagged as the receiver: this is FR-013's blocking condition — the preview must flag that a receiver is required and block confirmation; no envelope balances are written. This is a distinct failure mode from over-allocation below (here, income is left over; there, too much was claimed).
   - If `leftover == 0`: no receiver involvement needed regardless of whether one is flagged (nothing to add).
   - If `leftover < 0` (i.e. `claimed > income_entered`): this is the over-allocation condition (FR-011a) — the preview must flag it and block confirmation; no envelope balances are written.

**Rationale**: SC-002 requires the sum of all envelope changes in an event to exactly equal the income entered, with no drift. Rounding each percentage share independently and then reconciling the total difference against a single designated receiver (rather than, say, adjusting individual shares to force them to sum correctly) is deterministic, simple to explain to the user, and matches the spec's own framing of the receiver's role. Round-half-up is used for individual share rounding because it is the simplest, most predictable rounding rule for end users reviewing a preview (vs. round-half-to-even, which can look inconsistent to a non-technical user comparing two similar percentages).

**Alternatives considered**:
- Largest-remainder method (apportion the 1-VND leftovers to the envelopes with the largest fractional remainders, largest-first) — more "fair" in the abstract but adds complexity and unpredictability to the preview UI (users would see seemingly arbitrary envelopes getting +1 VND) for a currency where the unit is already the smallest one; rejected as over-engineering for VND-only scope.
- Floating-point math with epsilon comparison — rejected outright per constitution Principle I/II (money math must be exact); use integer VND arithmetic throughout (`int` in Dart, not `double`).

## 2. Server-authoritative balance reconciliation

**Decision**: Drift stores a materialized `balance` column on `envelopes`, updated transactionally by the same local write that inserts the allocation-event line / expense entry / coverage row (all in one Drift transaction, alongside the outbox insert). On the Supabase side, a Postgres view (`envelope_balances`) recomputes each envelope's balance from its full transaction log (`allocation_event_lines` + `expense_entries` + `envelope_coverages`) rather than trusting a synced column. The sync worker periodically compares the local materialized balance against this view (once connectivity allows) and surfaces a reconciliation warning if they diverge — they should never diverge under correct sync, so a divergence indicates a missed/corrupted sync event worth surfacing rather than silently overwriting.

**Rationale**: Constitution's Offline-First section explicitly requires this pattern ("the client MUST NOT trust a locally computed balance as final ... MUST reconcile against a balance recomputed from the transaction log on the Supabase side"). Materializing the balance locally is still necessary for instant offline reads (Overview must render instantly per Principle IV); the view-based recomputation is the audit mechanism, not the primary read path.

**Alternatives considered**: Recomputing envelope balance from the transaction log on every local read (no materialized column) — rejected as unnecessary overhead for a value read on every Overview render; the constitution's requirement is about *trusting* the value as final for sync purposes, not about how local reads are served.

## 3. Rounding-remainder receiver representation

**Decision**: `envelopes.is_rounding_receiver BOOLEAN NOT NULL DEFAULT false`, enforced to at most one `true` row per `user_id` via a partial unique index (`WHERE is_rounding_receiver`) in both Drift (via a check in the repository's write path, since Drift/SQLite has no native partial-unique DDL) and Supabase Postgres (native partial unique index).

**Rationale**: Spec's Key Entities section describes this literally as an attribute of Envelope ("rounding-remainder-receiver flag"), not a separate settings concept — a boolean column on the existing table is the most direct mapping and avoids introducing a new single-row settings table just to hold one FK.

**Alternatives considered**: A `user_settings.rounding_receiver_envelope_id` FK column — technically equivalent, but adds a table whose only purpose is one column, and separates a concept the spec treats as envelope-local; rejected for unnecessary indirection.

## 4. Allocation-event breakdown shape

**Decision**: Normalized `allocation_event_lines` table (`event_id`, `envelope_id`, `amount`, `is_rounding_remainder` bool) — one row per envelope per allocation event.

**Rationale**: FR-010 explicitly persists the breakdown "for future reporting"; a normalized table is queryable/aggregable (e.g. "total allocated to Savings over time") without parsing JSON, and fits Drift's relational strengths (indexed joins, typed columns) that the constitution calls out as the reason Drift was chosen over a key-value store.

**Alternatives considered**: A JSON/text blob column on `allocation_events` holding the breakdown — simpler to write but defers all future reporting cost to a JSON-parsing migration; rejected since the spec already flags future reporting as the explicit reason this data is persisted at all.

## 5. Authentication flow

**Decision**: Supabase Auth email + password (`supabase.auth.signInWithPassword`, `signUp`, `updateUser` for password change).

**Rationale**: Spec FR-026 explicitly requires in-app password change, which is only meaningful for a password-based auth method — a magic-link/OTP-only flow would make "change password" a non-sequitur. This isn't a close call between alternatives; the requirement itself determines the method.

**Alternatives considered**: Magic link / OTP — incompatible with FR-026 as written; not pursued.

## 6. Navigation shell for the 4 tabs

**Decision**: `go_router`'s `StatefulShellRoute.indexedStack`, one branch per tab (Overview, Spending, Envelopes, Account), with a top-level `redirect` callback reading `core/auth`'s session-state provider to send unauthenticated users to a sign-in route before any tab is reachable (FR-025).

**Rationale**: `StatefulShellRoute.indexedStack` preserves each tab's navigation stack and scroll position when switching tabs, which is the standard, unsurprising behavior users expect from bottom-nav apps and is what the constitution's UX Consistency principle means by "MUST NOT invent a bespoke pattern where an existing one applies." Plain nested routes without the shell would reset tab state on every switch, a worse and non-standard experience.

**Alternatives considered**: A `BottomNavigationBar` + `IndexedStack` built manually without `go_router`'s shell route — works, but `go_router` is already a declared dependency and its shell route gives deep-linkable, back-button-correct routes per tab for free; rejected as reinventing an already-available, better-tested mechanism.

## 7. Sync outbox scope for this feature's first pass

**Decision**: In scope, not deferred. Every write path in this feature (envelope CRUD, allocation-event confirmation, expense entry create/edit/delete, coverage transfer) commits to Drift and appends a row to `sync_outbox` in the same local transaction. A background worker drains the outbox to Supabase when connectivity is available (simple periodic + connectivity-change-triggered drain, exponential backoff on failure — not a fully-featured scheduler; that refinement can iterate later without changing the write-path contract).

**Rationale**: Constitution's Offline-First section states the outbox pattern with "MUST," and this feature is the first to perform any real local writes — deferring sync here would mean the very first financial data in this app has no path to the server at all, which the constitution does not allow as an acceptable interim state. The worker's internal scheduling sophistication can be minimal for v1 (the write-path contract — transactional outbox insert — is the part that must be right from day one and is expensive to retrofit).

**Alternatives considered**: Defer sync entirely for this feature, add it in a follow-up — rejected; would require a Complexity Tracking justification for skipping a constitutional MUST, and no such justification holds (this isn't a prototype/spike, it's the app's first real financial feature).
