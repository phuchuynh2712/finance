# Feature Specification: Transaction History

**Feature Branch**: `20260924-071637-transaction-history`

**Created**: 2026-09-24

**Status**: Draft

**Input**: User description: "Build a page for viewing transaction history, using the supplied transaction-history handoff package as a long-term reference."

## Clarifications

### Session 2026-09-24

- Q: How should transaction names and groups behave after their source item changes or is deleted? → A: Keep the name and group captured when the transaction was recorded.
- Q: Which groups should be available as monthly-history filters after a group is deleted? → A: Show every group with matching transactions in the selected month, including deleted groups.
- Q: How should existing transactions gain immutable name and group snapshots? → A: Backfill each existing transaction from its current name and group, then retain that snapshot.
- Q: What name should an income history row use when an income save updates multiple recipient items? → A: Use the recipient item's name and the Income classification for each row.
- Q: How should an existing transaction be shown when its source item is already unavailable for backfill? → A: Retain the transaction with the Archived Item label and its applicable classification.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Review Monthly Transactions (Priority: P1)

As a signed-in user, I want to open my transaction history from the Spending hub and review the transactions recorded for a selected month, so that I can understand where my money went.

**Why this priority**: Viewing recorded income and expenses is the core value of the screen and replaces the existing unavailable-state destination.

**Independent Test**: A user with transactions in the current month can open the history from the Spending hub and identify each transaction, its date, category, and signed amount.

**Acceptance Scenarios**:

1. **Given** the user is on the Spending hub, **When** they select "View transaction history", **Then** the transaction-history screen opens without bottom navigation and shows the current month by default.
2. **Given** the selected month contains transactions, **When** the screen loads, **Then** transactions are grouped by occurrence date from newest to oldest and each row shows its name, category context, type icon, and signed formatted amount.
3. **Given** the selected month contains expense transactions, **When** the monthly summary is shown, **Then** it displays the total of that month's expenses and excludes income amounts.

---

### User Story 2 - Browse Another Month (Priority: P2)

As a user, I want to move between months in my transaction history, so that I can compare my spending across time.

**Why this priority**: A history limited to the current month would not let users review previous financial activity.

**Independent Test**: Starting from a month with known transactions, the user can move to an adjacent month and sees only that month's summary and transaction groups.

**Acceptance Scenarios**:

1. **Given** the history screen is showing a month, **When** the user selects the previous-month control, **Then** the screen shows the preceding calendar month and updates the transaction list and expense total.
2. **Given** the history screen is showing a past month, **When** the user selects the next-month control, **Then** the screen shows the following calendar month and updates the transaction list and expense total.
3. **Given** the history screen is showing the current month, **When** the user attempts to move to a future month, **Then** the current month remains selected and no future-month data is shown.

---

### User Story 3 - Filter Monthly History (Priority: P3)

As a user, I want to filter a selected month's history by budget group or income, so that I can focus on a particular type of financial activity.

**Why this priority**: Filters make a long monthly list practical to scan while preserving an all-transactions default.

**Independent Test**: With a selected month containing transactions from multiple budget groups and income, choosing each available filter returns only matching rows.

**Acceptance Scenarios**:

1. **Given** the history screen opens, **When** the user has not selected another filter, **Then** the All filter is active and every transaction in the selected month is shown.
2. **Given** budget groups are available to the user, **When** the user selects one group, **Then** only expense transactions associated with that group are shown and the active selection is clear.
3. **Given** the user selects the Income filter, **When** matching income transactions exist, **Then** only income transactions for the selected month are shown.

### Edge Cases

- A selected month with no matching transactions shows an understandable empty state and retains the selected month and filter.
- A budget group with no transactions in the selected month can still be selected and produces the empty state rather than stale results.
- Transactions recorded on the same calendar day appear under one date heading, regardless of their type.
- An existing transaction whose unavailable source prevents label backfill remains visible with the Archived Item label and its applicable classification.
- If history data cannot be loaded, the user sees an understandable error state with a way to retry while retaining the selected month and filter.
- Long transaction names and category labels remain identifiable without obscuring the amount or making the row unusable.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST open the transaction-history screen from the Spending hub's transaction-history action and return the user to the hub when they use the back action.
- **FR-002**: The system MUST initially show the current calendar month and MUST prevent navigation beyond the current month.
- **FR-003**: The system MUST let users move one calendar month backward or forward when the destination month is not in the future.
- **FR-004**: The system MUST show the selected month and that month's total expenses, excluding income from the total.
- **FR-005**: The system MUST show all of the user's transactions in the selected month by default, grouped by local calendar date in descending date order.
- **FR-006**: Each transaction row MUST identify the transaction name and group or income classification captured when the transaction was recorded, an appropriate transaction-type icon, and a localized signed monetary amount.
- **FR-006a**: Each income transaction row MUST use the recipient item's captured name and the Income classification, even when one income save updates multiple recipient items.
- **FR-007**: The system MUST distinguish income and expense amounts using the application's established semantic colors and signs.
- **FR-008**: The system MUST offer a single-select filter with All selected by default, one option for each available budget group, and an Income option.
- **FR-009**: Selecting a budget group MUST show only matching expense transactions; selecting Income MUST show only income transactions; selecting All MUST restore every transaction in the selected month.
- **FR-009a**: The group-filter options for a selected month MUST include every group represented by that month's expense transactions, including a group that has since been deleted.
- **FR-009b**: Before immutable transaction-history labels take effect, the system MUST populate each existing transaction's label snapshot from its current associated name and group.
- **FR-009c**: If an existing transaction's source item is unavailable when snapshots are populated, the system MUST retain the transaction and use the Archived Item label with its applicable classification.
- **FR-010**: The system MUST provide clear loading, empty, and recoverable error states without discarding the user's selected month or filter.
- **FR-011**: The screen MUST remain usable in the application's supported light and dark appearance modes and provide touch targets large enough for reliable use.

### Key Entities *(include if feature involves data)*

- **Financial Transaction**: A user-recorded income or expense with an amount, direction, occurrence date, transaction-type icon, and immutable name and category context captured when it is recorded or backfilled from its current associated item for an existing transaction; income uses its recipient item's name and the Income classification, while an unavailable backfill source uses the Archived Item label.
- **Budget Group**: A user-visible grouping that can be associated with expense transactions and used as a history filter; groups with matching historical transactions remain filterable after deletion.
- **Monthly History View**: The selected calendar month, active filter, expense total, and date-grouped transaction results shown to the user.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In usability testing, at least 95% of participants can open the transaction-history view from the Spending hub and identify the current month's expense total within 30 seconds.
- **SC-002**: In usability testing, at least 90% of participants can navigate to an adjacent month and correctly identify whether it contains transactions within 20 seconds.
- **SC-003**: For a month containing at least 100 transactions, users can apply a group or income filter and see the updated matching list within 1 second of selection under normal operating conditions.
- **SC-004**: All tested transactions in the selected month appear exactly once in the All view, with the correct date group and signed amount.
- **SC-005**: All primary flows remain completable in both supported appearance modes without clipped essential information or inaccessible controls.

## Assumptions

- The existing signed-in user's recorded income and expense history is the authoritative source for this view; no new transaction entry behavior is included.
- Dates, month labels, and monetary amounts use the application's active locale and currency conventions.
- Budget-group filters are generated from all groups represented by expense transactions in the selected month, including deleted groups; Income is a fixed filter option.
- Transaction-history labels retain the name and group captured at recording time, even if the source item is later renamed or deleted.
- Existing transactions receive their initial immutable history labels by copying the currently associated name and group before this feature takes effect.
- An existing transaction whose source item is unavailable during backfill remains in history with the Archived Item label and its applicable classification.
- When one income save updates multiple recipient items, each resulting history row uses its recipient item's captured name and the Income classification.
- The supplied handoff package is the visual reference for this screen, including its no-bottom-navigation presentation and established light/dark styling.
- Text search is not included in this feature because the handoff provides no search behavior or results design; its visual control is outside the functional scope of this release.
- The existing bottom-navigation Report placeholder is outside this feature; this feature replaces only the transaction-history destination from the Spending hub.