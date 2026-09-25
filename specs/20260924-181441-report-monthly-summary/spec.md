# Feature Specification: Monthly Report Screen

**Feature Branch**: `20260924-181441-report-monthly-summary`

**Created**: 2026-09-24

**Status**: Draft

**Input**: User description: "Cần rebase và resolve conflict để đảm bảo branch code mới nhất. Trao đổi bằng tiếng việt. viết spec, plan,... code bằng tiếng anh. Đọc tất cả nội dung trong folder \"E:\Study\design\bao-cao-package\". Lưu giữ những cái liên quan để làm reference về lâu dài. Tôi muốn làm trang báo cáo, cần thay đổi icon dưới nav và trang báo cáo có thể thấy được thu nhập và chi tiêu trong tháng."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See this month's income and expense totals (Priority: P1)

A user opens the "Báo cáo" (Report) tab to understand, at a glance, how much
money came in and how much went out during the currently selected month.

**Why this priority**: This is the core value of the feature — without the
two totals, there is no report. Every other capability in this feature
builds on having a month selected and its totals computed.

**Independent Test**: Can be fully tested by opening the Report tab and
confirming it shows an income total and an expense total for the current
calendar month, computed from the user's actual recorded transactions.

**Acceptance Scenarios**:

1. **Given** the user has recorded transactions in the current month, **When**
   they open the Report tab, **Then** they see one total for income and one
   total for expenses, both reflecting only transactions dated within that
   month.
2. **Given** the user has income and expense transactions in different
   months, **When** they view the Report tab for the current month, **Then**
   transactions from other months are excluded from both totals.

---

### User Story 2 - Browse totals for a different month (Priority: P2)

A user wants to review a past month's income and expenses, not just the
current one, to check how a specific month went.

**Why this priority**: Extends the core totals (User Story 1) with the
ability to look backward — high value for a personal finance report, but
the screen is still useful without it, so it ranks below the base totals.

**Independent Test**: Can be fully tested by navigating to a previous month
from the Report tab and confirming the totals and item breakdown update to
match that month's transactions, independent of any other capability.

**Acceptance Scenarios**:

1. **Given** the user is viewing the current month's report, **When** they
   navigate to the previous month, **Then** the displayed month label, the
   income/expense totals, and the item breakdown all update to reflect that
   earlier month's transactions.
2. **Given** the user has navigated to a past month, **When** they navigate
   forward again, **Then** they can return step by step up to the current
   month.
3. **Given** the user is viewing the current (latest) month, **When** they
   look at the forward-navigation control, **Then** it does not let them
   advance into a future month.

---

### User Story 3 - See how much of each item's monthly budget was used (Priority: P2)

A user wants to see, item by item, how much they spent and whether that
spending stayed within what was set aside for that item this month, so they
can tell at a glance where they're on track and where they've overspent.

**Why this priority**: Adds the "why" behind the expense total from User
Story 1 — high value for a report, but the screen already delivers value
with totals alone, so this ranks alongside month browsing rather than above
the base totals.

**Independent Test**: Can be fully tested by opening the Report tab for a
month with recorded items and confirming a breakdown list appears, showing
each item's name, which group it belongs to, the amount spent from it, and
how much of that item's allocation for the month has been used.

**Acceptance Scenarios**:

1. **Given** the selected month has items that received an income
   allocation and/or expense activity, **When** the user views the
   breakdown list, **Then** each item shows its own name, the name of the
   group it belongs to (for identification), the amount spent from it this
   month, and — when it also received an allocation this month — a visual
   indicator of how much of that allocation has been used.
2. **Given** an item received an income allocation this month but has had
   no expenses yet, **When** the user views the breakdown list, **Then** it
   appears showing 0% of its allocation used.
3. **Given** an item has expense activity this month but received no
   income allocation within that same month, **When** the user views the
   breakdown list, **Then** it appears with a distinct "not allocated this
   month" indicator instead of a misleading or undefined percentage.
4. **Given** an item had neither income nor expense activity in the
   selected month, **When** the user views the breakdown list, **Then**
   that item does not appear in the list.

---

### Edge Cases

- What happens when the selected month has no transactions at all (income
  and expenses both zero)? The two total cards still display (both showing
  a zero amount), and the item breakdown area shows an empty-state message
  instead of a list.
- What happens when an item has expense activity in the selected month but
  received no income allocation within that same month (e.g. spent from a
  balance built up in an earlier month)? It appears in the list with a
  distinct "not allocated this month" indicator rather than a percentage —
  this usage percentage is deliberately scoped to the selected month's own
  activity only and does not draw on any earlier month's leftover balance
  (see Assumptions).
- What happens when the user rapidly taps the forward/back month controls?
  Each navigation replaces the previous one — the user always ends up
  viewing whichever month they most recently navigated to, with no
  cumulative or duplicated view.
- How far back can a user navigate? There is no fixed limit — navigation
  continues back through any month that has data, consistent with the
  existing history/transaction browsing behavior elsewhere in the app.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The bottom navigation's fourth tab icon MUST be changed to a
  pie-chart icon, replacing its current icon. The tab's label ("Báo cáo")
  and position are unchanged.
- **FR-002**: Selecting the fourth tab MUST open a Report screen instead of
  its current "not available" placeholder.
- **FR-003**: The Report screen MUST default to showing the current
  calendar month on first open.
- **FR-004**: The Report screen MUST display the currently selected month
  in a human-readable label (e.g., month and year).
- **FR-005**: The Report screen MUST let the user move to the previous
  month and, when not already on the current month, to the next month.
- **FR-006**: The Report screen MUST prevent navigating past the current
  (latest) month into a future month.
- **FR-007**: The Report screen MUST display the total income for the
  selected month as a single summed amount.
- **FR-008**: The Report screen MUST display the total expenses for the
  selected month as a single summed amount.
- **FR-009**: Both totals MUST include only transactions dated within the
  selected month and MUST exclude transactions from any other month.
- **FR-010**: The income total MUST be shown as a single aggregate figure
  only — no per-source breakdown of income is required.
- **FR-011**: The Report screen MUST display a breakdown listing every item
  that had income allocation and/or expense activity within the selected
  month; an item with neither in that month MUST NOT appear.
- **FR-012**: Each row in the breakdown MUST show the item's own name, the
  name of the group it belongs to (so the user can tell which group it's
  part of without a nested/expandable list), and the amount spent from it
  in the selected month.
- **FR-013**: When an item received an income allocation within the
  selected month, its row MUST show a visual indicator of what percentage
  of that month's allocation has been used, computed only from that
  month's own income-allocation and expense amounts for that item (no
  earlier month's leftover balance is factored in).
- **FR-014**: When an item has expense activity in the selected month but
  received no income allocation within that same month, its row MUST show
  a distinct "not allocated this month" indication instead of a numeric
  percentage or ratio.
- **FR-015**: When the selected month has no income and no expense
  transactions, the Report screen MUST still show both total cards (with a
  zero amount) and MUST show an empty-state message in place of the item
  breakdown list.
- **FR-016**: The Report screen's totals and breakdown MUST update whenever
  the user changes the selected month, without requiring a manual refresh.

### Key Entities

- **Monthly Report**: A read-only, derived view for one calendar month,
  consisting of a total income amount, a total expense amount, and a
  per-item spending breakdown — all computed from the user's existing
  recorded transactions for that month.
- **Item Spending Entry**: One item's amount spent in the selected month,
  the name of its parent group (for identification only), and — when that
  item also received an income allocation within the same month — the
  percentage of that allocation used so far.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can determine their total income and total expenses
  for the current month within 2 seconds of opening the Report tab.
- **SC-002**: A user can view any past month's income, expenses, and item
  breakdown using only the month-navigation control, without leaving the
  Report screen.
- **SC-003**: A user can identify their single largest spending item for a
  given month at a glance, without needing to open any other screen.
- **SC-004**: A user can tell whether their spending on any item has
  stayed within, or gone over, that item's allocation for the month
  without doing their own math.
- **SC-005**: 100% of a month's recorded income and expense transactions
  are reflected in that month's totals and breakdown — no transaction is
  silently omitted or double-counted.

## Assumptions

- The breakdown list is flat, one row per item — it does not nest items
  under an expandable group header. A row identifies its group by name
  only, so the user can still tell where an item belongs without a
  drill-down interaction.
- An item's usage percentage (FR-013) is intentionally scoped to the
  selected month's own income-allocation and expense activity only. It
  does not draw on any balance carried over from an earlier month. This is
  an accepted simplification for this iteration — if it later proves
  confusing (e.g. because income isn't always saved on a strict monthly
  cadence), a version that accounts for carried-over balance can be
  revisited as a separate enhancement.
- The Report screen reuses the app's existing recorded transaction history
  as its data source — this feature introduces no new way of recording
  income or expenses, only a new way of viewing totals already captured by
  existing features.
- An item's displayed name and group reflect its current name/grouping at
  the time the report is viewed, not necessarily how it was named or
  grouped at the time each transaction occurred, for any item that still
  exists. An item that has since been removed is still shown for a past
  month it had activity in, identified in a way consistent with how
  removed items are already shown elsewhere in the app.
- Month navigation has no fixed historical limit; a user can browse back
  through any past month that has data, consistent with existing
  transaction-browsing behavior elsewhere in the app.
- Only the fourth bottom-navigation tab's icon changes (per the source
  design). Its label and its position among the five tabs are unchanged.
- The design reference materials in `reference/` (screenshots, detailed
  layout notes, icon mapping, and theme tokens) describe the source visual
  direction this feature started from; the breakdown's presentation
  described there (grouped, with a single share-of-total-expense bar) was
  superseded during specification by the flat, per-item, budget-usage
  approach captured above — kept for the parts that still apply (header,
  month selector, total cards, overall screen structure) and as long-term
  design-history reference.
