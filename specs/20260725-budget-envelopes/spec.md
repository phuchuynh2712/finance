# Feature Specification: Budget Envelopes

**Feature Branch**: `20260725-budget-envelopes`

**Created**: 2026-07-26

**Status**: Draft

**Input**: User description: "Budget envelope feature: users configure budget envelopes (percentage-based or fixed-amount) from their income, plan/allocate income into envelopes (possibly multiple times per month, additive), track spending against envelopes with inline overspend coverage from another envelope, and navigate via 4 tabs (Overview, Spending, Envelopes, Account) with Overview as the default landing tab." (full detail in `specs/input-budget-envelopes.md`)

## Clarifications

### Session 2026-07-26

- Q: Should percentage-based envelope allocations be computed against the total income entered in the event, or against the remainder after fixed-amount envelopes are deducted first? → A: Percentage is always computed against the full income amount entered, independent of fixed-amount envelopes; fixed and percentage allocations are each computed independently, then both applied.
- Q: Any income not claimed by fixed or percentage envelopes (distinct from rounding dust) — does it also flow to the rounding-remainder receiver, stay unallocated, or block plan confirmation? → A: It also flows to the rounding-remainder receiver, same as rounding dust. By design, percentage-based envelopes are expected to sum to 100% of income, so in practice this leftover is almost always just rounding dust — but the receiver's mechanism handles any unclaimed amount generically, not only sub-unit rounding differences.
- Q: Since fixed-amount and percentage-based envelopes are each computed independently against the full income entered (previous answer), their combined total can exceed the income entered when both types coexist in one allocation event — should this be warned/blocked, silently allowed, or auto-scaled down? → A: Envelope allocation method remains per-envelope (percentage or fixed, as originally designed) and both types may coexist within a single allocation event. When their combined total would exceed the income entered, the system warns and blocks confirmation, using the same mechanism as the existing negative-balance warning (FR-011/FR-012).
- Q: Can a saved expense entry be edited or deleted afterward, and if so, how are its envelope-balance and linked coverage effects handled? → A: Both edit and delete are allowed. Editing or deleting first reverses the original entry's effects (restores the envelope balance, and reverses any linked covering-envelope transfer), then — for an edit — reapplies the new values, including re-running the overspend/covering-envelope flow if the edited amount still overspends the target envelope.
- Q: When an expense would overspend its envelope but no other envelope exists to select as a coverer, what happens? → A: The covering-envelope selection step is skipped and the expense saves normally, leaving the target envelope negative — flagged the same as any other negative balance on Overview.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Allocate Income Into Envelopes (Priority: P1)

A user receives income (salary, bonus, freelance payment) and wants to distribute it across their pre-configured budget envelopes according to each envelope's allocation rule, so their money is proactively assigned to a purpose instead of sitting as one undifferentiated balance.

**Why this priority**: This is the core value proposition of envelope budgeting — without the ability to allocate income, envelopes are just empty labels. It's also a prerequisite for Spending (US2) to be meaningful, since spending is tracked against envelope balances this flow creates.

**Independent Test**: With at least one percentage-based and one fixed-amount envelope already configured, open the Overview tab, start a "Plan" action, enter an income amount, review the calculated per-envelope breakdown (including rounding remainder), confirm, and verify each envelope's balance increased by the correct amount.

**Acceptance Scenarios**:

1. **Given** the user has 3 envelopes configured (30% "Savings", fixed 5,000,000₫ "Rent", and "Buffer" flagged as the rounding-remainder receiver) and enters 20,000,000₫ income, **When** they review the allocation preview, **Then** it shows Rent receiving exactly 5,000,000₫, Savings receiving 30% of the full 20,000,000₫ income (6,000,000₫) — computed independently of the Rent deduction — and Buffer receiving the remaining 9,000,000₫ not claimed by either, so the three allocations sum to exactly 20,000,000₫.
2. **Given** an allocation event has been confirmed once this month, **When** the user runs a second "Plan" action with a new income amount, **Then** each envelope's balance is increased by the new event's allocation on top of its existing balance (not reset or replaced).
3. **Given** percentage allocations produce rounding remainders (e.g. splitting 100,000₫ three ways at 33.3% each), **When** the allocation is calculated, **Then** the leftover from rounding is added entirely to the envelope flagged as the rounding-remainder receiver, and the sum of all envelope allocations exactly equals the income entered.
4. **Given** the sum of fixed-amount envelope allocations would exceed the income entered in this event, **When** the user reviews the preview, **Then** the affected envelope(s) are highlighted in red with a suggested adjustment, and the user cannot confirm the plan until it is resolved.
5. **Given** the combined total of fixed-amount and percentage-based allocations (computed independently, per FR-004/FR-005) would exceed the income entered even though no single envelope's balance goes negative, **When** the user reviews the preview, **Then** the over-allocation is flagged with the excess amount shown, and the user cannot confirm the plan until it is resolved.

---

### User Story 2 - Record Spending With Inline Overspend Coverage (Priority: P1)

A user makes a purchase and wants to log it against the correct envelope immediately, so their envelope balances stay an accurate reflection of what's actually left to spend — and if the purchase overspends that envelope, resolve the shortfall right away instead of leaving the balance negative.

**Why this priority**: Tracking spending is the second half of the envelope method's core loop (allocate → spend → see what's left) and is equally load-bearing as US1; the two together are the minimum viable product. It's P1 alongside US1 because a budgeting app that can allocate but not track spending delivers no ongoing value.

**Independent Test**: With an envelope holding a known balance, add a manual expense entry against it for an amount less than the balance and confirm the balance decreases correctly; then add an expense exceeding the balance and confirm the inline covering-envelope prompt appears and both envelopes update correctly after resolution.

**Acceptance Scenarios**:

1. **Given** the "Groceries" envelope has a 2,000,000₫ balance, **When** the user logs a 500,000₫ expense against it with a date and optional note, **Then** the Groceries balance becomes 1,500,000₫ and the expense is saved with its amount, envelope, date, and note.
2. **Given** the "Groceries" envelope has a 300,000₫ balance, **When** the user logs a 500,000₫ expense against it, **Then** the system prompts the user to choose a covering envelope before the expense is saved, showing the 200,000₫ shortfall.
3. **Given** the user selects "Entertainment" (balance 1,000,000₫) as the covering envelope for a 200,000₫ shortfall, **When** they confirm, **Then** Groceries' balance becomes 0₫, Entertainment's balance becomes 800,000₫, and the expense entry plus the cross-envelope coverage are both saved.
4. **Given** the user is on the covering-envelope prompt, **When** they cancel instead of selecting a covering envelope, **Then** the expense entry is not saved and no envelope balance changes.
5. **Given** a saved 500,000₫ "Groceries" expense with no overspend, **When** the user edits its amount down to 300,000₫, **Then** the original 500,000₫ is first restored to Groceries' balance, then 300,000₫ is deducted, netting a 200,000₫ balance increase versus before the edit.
6. **Given** a saved expense that triggered a covering-envelope transfer (per Scenario 3), **When** the user deletes that expense entry, **Then** the shortfall amount is restored to the covering envelope, the original amount is restored to the source envelope, and the coverage record is removed along with the expense entry.
7. **Given** a saved expense with no overspend, **When** the user edits its amount upward such that it would now overspend the target envelope, **Then** the covering-envelope prompt is triggered for the new shortfall before the edit is saved, same as for a new entry.
8. **Given** the user has only one envelope in total and it would be overspent by a new expense, **When** they save the expense, **Then** no covering-envelope prompt appears (there is no other envelope to select), the expense saves normally, and the envelope's balance goes negative.

---

### User Story 3 - Configure Envelopes (Priority: P2)

A user sets up and maintains their budget structure — creating envelopes for each spending category, defining how each one is funded (percentage or fixed amount), and designating which envelope absorbs rounding leftovers.

**Why this priority**: Configuration must exist before US1/US2 can be used at all, but it's a one-time/infrequent setup activity rather than an ongoing loop — once envelopes exist, users spend far more time on US1/US2. It's P2 because a demo could seed default envelopes to demonstrate US1/US2, but real usage requires this.

**Independent Test**: From the Envelopes tab, create a new envelope with a name and percentage allocation, edit an existing envelope's fixed amount, delete an unused envelope, and flag one envelope as the rounding-remainder receiver — verify each change is reflected immediately and persists across app restarts.

**Acceptance Scenarios**:

1. **Given** the user is on the Envelopes tab, **When** they create a new envelope named "Travel" with a 10% allocation, **Then** it appears in the envelope list with a 0₫ starting balance and is available for selection in future allocation and spending flows.
2. **Given** two envelopes already exist, **When** the user flags a third envelope as the rounding-remainder receiver, **Then** the previous receiver (if any) is automatically unflagged, since exactly one envelope may hold this role at a time.
3. **Given** an envelope has a non-zero balance, **When** the user attempts to delete it, **Then** the system warns that its balance and history will be affected before allowing deletion to proceed.
4. **Given** the user edits an envelope's allocation method from percentage to fixed amount (or vice versa), **When** they save the change, **Then** the new method applies to all future allocation events; past allocation event records are not retroactively recalculated.

---

### User Story 4 - View Envelope Overview and Manage Account (Priority: P3)

A user opens the app and wants an immediate, at-a-glance picture of where every envelope stands, with overspent envelopes clearly flagged — plus basic account management (login, avatar, password).

**Why this priority**: This is the landing experience and lowest-friction "check-in" use case, but it's read-mostly (except for launching the Plan action, covered under US1) and depends on US1/US2/US3 already having produced data to display. Account management is standard, low-risk, and not differentiating.

**Independent Test**: With a mix of positive and negative (overspent) envelope balances, open the Overview tab and verify all envelopes are listed with correct balances and that negative ones are visually flagged (e.g. red); separately, verify the Account tab supports login, avatar update, and password change.

**Acceptance Scenarios**:

1. **Given** the user has 4 envelopes with varying balances, **When** they open the app, **Then** Overview is the tab shown by default and lists all 4 envelopes with their current balances.
2. **Given** an envelope has a negative balance (e.g. from an unresolved edge case or data correction), **When** viewing Overview, **Then** that envelope is visually distinguished (e.g. red) from envelopes with non-negative balances.
3. **Given** the user is on the Account tab, **When** they update their avatar or change their password, **Then** the change is saved and reflected immediately.
4. **Given** the user is not logged in, **When** they open the app, **Then** they are directed to authenticate before reaching Overview.

---

### Edge Cases

- What happens when a user enters an income amount of 0 or a negative number in the Plan flow? System MUST reject the input before showing an allocation preview.
- What happens when no envelope is flagged as the rounding-remainder receiver and a percentage allocation produces a nonzero remainder? System MUST prevent confirming the plan until either a receiver is flagged or all percentages sum in a way that produces no remainder (see FR-013).
- What happens when the user tries to log an expense but no envelopes exist yet? System MUST direct the user to create an envelope first (Envelopes tab) rather than allowing an expense with no envelope target.
- What happens when the shortfall from an overspend exceeds every other envelope's individual balance (no single envelope can fully cover it)? System MUST allow the user to select a covering envelope even if it would also go negative, since forcing a resolution here would block the user from saving the expense at all — but the resulting negative balance is then flagged per US4's Overview behavior.
- What happens when an overspend occurs and no other envelope exists at all to select as a coverer (e.g. only one envelope exists)? Per FR-016, the covering-envelope step is skipped entirely and the expense saves with the target envelope going negative, flagged the same as any other negative balance.
- What happens when a user deletes the envelope currently flagged as the rounding-remainder receiver? System MUST require the user to designate a new receiver among the remaining envelopes before the deletion completes, unless the user has no envelopes left, at which point the flag is simply cleared.
- What happens when percentage allocations alone sum to over 100%, or when fixed and percentage allocations combined exceed the income entered, even without any single envelope going negative? This is the over-allocation warning path covered by FR-011a/FR-012 — the preview flags the excess and blocks confirmation until resolved, distinct from (but using the same warning mechanism as) the per-envelope negative-balance path (FR-011/FR-012).
- What happens when a user edits or deletes an expense entry that was linked to a covering-envelope transfer? Per FR-018a, the coverage is reversed (shortfall restored to the covering envelope) before the edit's new values are reapplied or the deletion completes — the coverage record itself is removed, not left dangling.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow users to create, edit, and delete budget envelopes, each with a name and an allocation method (percentage or fixed amount) with its associated value.
- **FR-002**: System MUST allow exactly one envelope at a time to be flagged as the "rounding remainder receiver"; flagging a new one automatically unflags the previous one.
- **FR-003**: System MUST allow the user to enter a total income amount and trigger an allocation ("Plan") event from the Overview tab.
- **FR-004**: System MUST compute each fixed-amount envelope's allocation as its configured exact amount for every allocation event, subject to FR-011's negative-balance check and FR-011a's over-allocation check.
- **FR-005**: System MUST compute each percentage-based envelope's allocation as `income_entered × percentage`, where `income_entered` is the total income amount entered in that event — independent of any fixed-amount envelope deductions, which are computed and applied separately (per Clarifications, Session 2026-07-26).
- **FR-006**: System MUST round each percentage-based envelope's calculated allocation to the nearest currency unit (whole VND — no subunit).
- **FR-007**: System MUST add any income not otherwise claimed by fixed-amount or percentage-based envelope allocations in an event — including both rounding dust from percentage math and any structural gap if configured percentages do not sum to exactly 100% — entirely to the envelope flagged as the rounding-remainder receiver, such that the sum of all envelope allocations in an event exactly equals the income entered (per Clarifications, Session 2026-07-26).
- **FR-008**: System MUST add each envelope's calculated allocation from an event to its existing balance (additive), never replacing or resetting prior balances.
- **FR-009**: System MUST support multiple allocation events within the same month, each independently persisted and additive.
- **FR-010**: System MUST persist every allocation event with its date, the income amount entered, and the resulting per-envelope allocation breakdown, even though no history UI is required in this scope.
- **FR-011**: System MUST detect, before an allocation event is confirmed, whether any envelope's resulting balance would be negative and visually flag the affected envelope(s) (e.g. red).
- **FR-011a**: System MUST detect, before an allocation event is confirmed, whether the combined total of fixed-amount and percentage-based allocations (each computed independently per FR-004/FR-005) would exceed the income amount entered, and visually flag this over-allocation condition — distinct from, and in addition to, any single envelope's negative-balance condition (per Clarifications, Session 2026-07-26).
- **FR-012**: System MUST propose an adjustment (e.g. suggest scaling down a fixed amount, or identify which envelope(s) to reduce) when a negative-balance condition (FR-011) or an over-allocation condition (FR-011a) is detected, and MUST NOT allow the plan to be confirmed while either is unresolved.
- **FR-013**: System MUST prevent confirming an allocation event if a nonzero rounding remainder exists and no envelope is flagged as the rounding-remainder receiver.
- **FR-014**: System MUST allow users to record an expense entry with an amount, a target envelope, a date, and an optional note/merchant.
- **FR-015**: System MUST decrease the target envelope's balance by the expense amount when an expense is saved.
- **FR-016**: System MUST detect, at expense-entry time, whether the expense would bring the target envelope's balance below zero, and if so, require the user to select a covering envelope before the expense can be saved — unless no other envelope exists to select, in which case the expense saves normally and the target envelope's balance goes negative (per Clarifications, Session 2026-07-26).
- **FR-017**: System MUST deduct the shortfall amount from the selected covering envelope's balance and record the cross-envelope coverage (source envelope, covering envelope, amount, date, linked expense) as part of saving the expense.
- **FR-018**: System MUST allow the user to cancel the covering-envelope selection, in which case the expense entry is discarded and no envelope balances change.
- **FR-018a**: System MUST allow users to edit or delete a previously saved expense entry. Editing or deleting MUST first reverse the original entry's effects (restore its amount to the target envelope's balance, and reverse any linked covering-envelope transfer by restoring the shortfall to the covering envelope and removing the coverage record); for an edit, the new values are then reapplied as if entered fresh, including re-triggering the covering-envelope prompt (FR-016) if the edited amount still overspends the target envelope (per Clarifications, Session 2026-07-26).
- **FR-019**: System MUST leave the receipt/OCR scanning capability out of this implementation while ensuring the expense-entry data model does not preclude adding it later (e.g. no schema assumption that entries are always manually typed).
- **FR-020**: System MUST display, on the Overview tab, every envelope's current balance, with negative balances visually flagged.
- **FR-021**: System MUST provide a "Plan" action on the Overview tab that opens the income allocation flow described in FR-003–FR-013.
- **FR-022**: System MUST NOT display allocation-event history in the UI in this scope, even though the underlying events are persisted per FR-010.
- **FR-023**: System MUST provide 4 bottom-navigation tabs — Overview (Tổng quan), Spending (Chi tiêu), Envelopes (Khoản), Account (Cá nhân) — with Overview as the default tab shown after login.
- **FR-024**: System MUST restrict envelope creation, editing, and allocation-method configuration to the Envelopes tab (no income entry occurs there).
- **FR-025**: System MUST support user authentication (login) via the existing Supabase Auth integration already present in the project scaffold, and route unauthenticated users to sign in before reaching Overview.
- **FR-026**: System MUST allow authenticated users to manage their avatar and change their password from the Account tab.
- **FR-027**: System MUST warn the user before deleting an envelope with a non-zero balance, describing the effect on that balance and its transaction history.
- **FR-028**: System MUST require designation of a new rounding-remainder receiver before completing deletion of the envelope currently holding that role, unless it is the user's last remaining envelope.
- **FR-029**: System MUST reject a "Plan" action with an income amount of zero or less before showing an allocation preview.
- **FR-030**: System MUST prevent expense entry when the user has no envelopes configured, directing them to create one first.

### Key Entities

- **Envelope**: A user-defined budget category. Attributes: name, allocation method (percentage or fixed amount), allocation value, current balance, rounding-remainder-receiver flag (at most one envelope per user has this set). Belongs to one user.
- **Allocation Event**: A single "Plan" action. Attributes: date/time, total income amount entered, and a breakdown of how much each envelope received in this event (including any rounding-remainder addition). Immutable once created; always additive to envelope balances. Belongs to one user.
- **Expense Entry**: A single spending transaction. Attributes: amount, target envelope, date, optional note/merchant, entry method (manual now; reserved for future scan-derived entries). Decreases its target envelope's balance. Unlike Allocation Event, may be edited or deleted after creation; doing so reverses and (for edits) reapplies its balance and coverage effects (per Clarifications, Session 2026-07-26).
- **Envelope Coverage** (cross-envelope transfer): Records an overspend resolution. Attributes: source envelope (the one that went negative), covering envelope, amount transferred, date, and a link to the triggering expense entry. Decreases the covering envelope's balance. Reversed automatically when its linked expense entry is edited or deleted.
- **User Account**: Existing Supabase Auth-backed identity. Attributes relevant here: avatar, password/credentials. Owns all envelopes, allocation events, and expense entries.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can complete a full income allocation (enter income, review preview, confirm) in under 30 seconds for a setup of up to 10 envelopes.
- **SC-002**: 100% of allocation events result in envelope balances whose sum of changes exactly equals the income amount entered (no silent rounding loss or overage).
- **SC-003**: A user can log a routine (non-overspend) expense entry in under 15 seconds from opening the Spending tab.
- **SC-004**: 100% of expense entries that would overspend an envelope trigger the inline covering-envelope prompt before saving — no path exists to save an expense that leaves an envelope negative without an explicit, recorded covering transaction.
- **SC-005**: Users can identify every overspent envelope within 5 seconds of opening the Overview tab (via visual flagging), without needing to open each envelope individually.
- **SC-006**: 100% of envelope configuration changes (create/edit/delete, rounding-receiver flag) persist correctly and are reflected in the very next allocation or spending flow without requiring an app restart.

## Assumptions

- Single currency (VND) per user; no multi-currency support in this scope, per the input document's explicit exclusion.
- VND has no practical subunit, so "smallest currency unit" for rounding purposes (FR-006) is 1 VND (whole number) — this mirrors standard VND handling and needs no further clarification.
- Receipt/OCR scanning is out of scope for this implementation pass; the data model's `entry method` field (Key Entities) is the extension point left open for it, per the input document's explicit guidance.
- Allocation-event history has no dedicated UI in this scope, but is fully persisted (FR-010) to support future reporting without a data migration.
- Users authenticate via the existing Supabase Auth setup already present in the project scaffold (per `specs/20260724-app-icon-theme` precedent and the input document's own suggested default); no new auth provider is introduced.
- Envelopes can be created and deleted freely at any time by the user (no approval workflow or locking period), consistent with a single-user personal-finance tool.
- A covering envelope is always chosen ad hoc at expense-entry time (FR-016); envelopes are not pre-configured in advance with a designated backup coverer, since the input document frames this as an inline, per-incident decision.
