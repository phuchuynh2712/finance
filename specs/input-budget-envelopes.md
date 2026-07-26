# Feature Input: Budget Envelopes (Income Allocation & Spending Tracking)

## Summary

A personal finance app that helps users split their monthly income into user-defined
"envelopes" (budget categories), track spending against each envelope, and stay in
control of how money is actually used — inspired by the envelope budgeting method.

## Core Concepts

- **Envelope**: a user-defined budget category (e.g. "Rent", "Groceries", "Savings").
  Each envelope has:
  - A name.
  - An allocation method: either a **percentage** of total income, or a **fixed amount**.
  - A running **balance** that accumulates when income is allocated and decreases when
    spending is recorded against it.
  - Optionally, one envelope can be flagged as the **rounding remainder receiver** — the
    envelope that absorbs leftover cents/units created by percentage rounding.
- **Plan / Income allocation event**: a single act of entering an income amount and
  having it distributed across envelopes according to their configured method. This can
  happen multiple times within the same month (e.g. salary + bonus + freelance income
  arriving separately). Each allocation event is an independent, additive transaction —
  it does not recompute or reset prior balances, it adds to them.
- **Expense entry**: a manual entry or receipt scan that records a spending transaction
  against a specific envelope, decreasing its balance.

## Allocation Calculation Rules

1. User enters a total income amount to allocate (a "plan" action).
2. For each envelope configured as **fixed amount**: that exact amount is allocated
   (subtracted from the pool of income being distributed this event).
3. For each envelope configured as **percentage**: its share is `income * percentage`.
   Percentage-based allocations are computed against the total income amount entered in
   that event (not against the remainder after fixed amounts — confirm this rule during
   `/speckit-clarify`; the important part is it must be deterministic and explained to
   the user).
4. Percentage-based math will commonly produce fractional/rounding remainders. All
   percentage allocations are rounded (to the currency's smallest unit), and the total
   leftover from rounding across all envelopes is dumped into the single envelope
   flagged as the "rounding remainder receiver."
5. Each envelope's allocated amount from this event is **added** to its existing
   balance (not replacing it) — supporting multiple allocation events per month.
6. If, after allocation, any envelope's resulting balance would be negative (relevant
   mainly when fixed-amount envelopes exceed the income being distributed), the UI
   should highlight it in red and let the user adjust the plan before confirming. The
   system should also propose an adjustment (e.g. suggest scaling down or flag which
   envelope(s) to reduce).
7. All allocation events are persisted individually in the data model (event date,
   income amount entered, resulting per-envelope allocation breakdown) even though the
   current UI scope does NOT need to display this history — it's for future reporting
   and data integrity.

## Spending & Overspend Handling

- Expenses can be entered manually or via receipt scan (scanning is a later-phase
  capability; the data model and expense-entry flow should not preclude adding OCR/scan
  later).
- Every expense entry is attributed to exactly one envelope, decreasing its balance.
- If an expense would bring an envelope's balance below zero (overspending that
  envelope), the user must choose another envelope to cover ("bù") the difference at
  the time of entry — i.e., overspend handling happens inline during expense entry, not
  as a separate reconciliation step elsewhere in the app. The chosen "covering" envelope
  has the shortfall amount deducted from it, and this cross-envelope transfer should
  also be recorded in the data model (which envelope covered which shortfall, when, and
  linked to which expense).

## Navigation / Tab Structure

The app has 4 bottom-navigation tabs (default landing tab after login: **Tổng quan /
Overview**):

1. **Tổng quan (Overview)** — default tab on login.
   - Shows the current balance of every envelope at a glance (visually flag envelopes
     that are negative or overspent, e.g. red).
   - Has a "Lập kế hoạch / Plan" action/button that opens the income-entry flow
     described above (enter income → preview calculated allocation, including rounding
     remainder handling and any negative-balance warnings/suggestions → confirm to
     apply as a new allocation event).
   - Does NOT show allocation-event history in the UI (data model still stores it).

2. **Chi tiêu (Spending)**
   - Manual expense entry and (future) receipt scanning.
   - Each entry: amount, envelope to deduct from, date, optional note/merchant.
   - If entry causes overspend on the chosen envelope, prompt the user to pick a
     covering envelope inline before the entry is saved.

3. **Khoản (Envelopes)** — configuration only, no income entry here.
   - Create / edit / delete envelopes.
   - Set allocation method per envelope (percentage or fixed amount) and the value.
   - Flag exactly one envelope as the rounding-remainder receiver.

4. **Cá nhân (Account)**
   - Login/auth, avatar management, change password.

## Open Questions for `/speckit-clarify`

- Exact order of operations when both fixed-amount and percentage envelopes exist in
  the same allocation event (percentage of full income vs. percentage of remainder
  after fixed deductions).
- What currency/locale and smallest rounding unit to assume (e.g. VND has no decimal
  subunit in practice — confirm rounding granularity).
- Whether an envelope can have zero or must have at least one covering envelope
  designated in advance, or the user always picks ad hoc at expense-entry time.
- Whether users can create/delete envelopes freely at any time, and what happens to an
  envelope's balance history if it's deleted while non-zero.
- Auth provider/method (this project already uses Supabase per the existing scaffold —
  confirm reusing Supabase Auth).
- Receipt scanning: explicitly out of scope for this feature's first implementation
  pass, or should the data model/UI leave a placeholder entry point now?

## Explicitly Out of Scope (for this spec)

- Receipt/OCR scanning implementation itself (data model should not block adding it
  later).
- Allocation-event history UI/reporting screens.
- Multi-currency support (assume single currency per user unless stated otherwise).
