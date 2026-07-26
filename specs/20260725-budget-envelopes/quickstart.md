# Quickstart: Budget Envelopes

How to verify this feature once implemented, mapped to the spec's acceptance scenarios.

## Prerequisites

- Drift `AppDatabase` includes the 5 tables from `data-model.md`, migrations applied
- `contracts/schema.sql` applied to the Supabase project (tables + RLS policies + `envelope_balances` view)
- `core/router/app_router.dart` wired into `main.dart` (`MaterialApp.router`), replacing the current single-screen `home:`
- A test user account exists (Supabase Auth) to sign in with

## Verify: Configure Envelopes (User Story 3)

1. Sign in → land on Overview (empty state, since no envelopes exist yet) → confirm FR-030 blocks navigating to Spending and adding an expense until at least one envelope exists.
2. Go to Envelopes tab → create "Rent" (fixed, 5,000,000₫), "Savings" (percentage, 30%), "Buffer" (percentage, 0%, flagged as rounding-remainder receiver) → confirm each appears immediately with a 0₫ balance.
3. Flag a different envelope as the rounding-remainder receiver → confirm "Buffer"'s flag is automatically cleared (FR-002, only one receiver at a time).
4. Attempt to delete "Buffer" while it still holds the receiver flag → confirm the app requires designating a new receiver first (FR-028), unless it's the last envelope.
5. Edit "Savings" from percentage to a fixed amount → confirm the change applies going forward only; re-check a previously confirmed allocation event's stored breakdown is untouched (FR-010's immutability).

## Verify: Allocate Income Into Envelopes (User Story 1)

1. From Overview, tap "Plan" → enter 20,000,000₫ → review the preview: Rent shows exactly 5,000,000₫, Savings shows exactly 6,000,000₫ (30% of the full 20,000,000₫, independent of Rent — per the FR-005 clarification), Buffer shows the remaining 9,000,000₫ → confirm the three sum to exactly 20,000,000₫ (SC-002).
2. Confirm the plan → verify each envelope's balance increased by exactly its previewed amount.
3. Run a second Plan action with a different income amount → confirm balances increase additively on top of the previous confirmed amounts, not reset (FR-008/FR-009).
4. Configure envelopes so fixed + percentage allocations would combine to exceed the income entered (e.g. Rent fixed 5,000,000₫ + two 60% envelopes on a 5,000,000₫ income) → confirm the preview flags the over-allocation and blocks confirmation until resolved (FR-011a — distinct from a single envelope going negative).
5. Enter 0 or a negative income amount → confirm the app rejects it before showing any preview (FR-029).

## Verify: Record Spending With Inline Overspend Coverage (User Story 2)

1. Log a routine expense against "Rent" for less than its balance → confirm the balance decreases by exactly the expense amount and the entry is saved with amount/envelope/date/note.
2. Log an expense against "Rent" that exceeds its balance → confirm the covering-envelope prompt appears showing the shortfall before the expense saves (FR-016).
3. Select "Savings" as the coverer → confirm: Rent's balance reflects the overspend resolved to 0 (or as configured), Savings' balance decreases by exactly the shortfall, and both the expense entry and the coverage record are saved (FR-017).
4. Cancel out of the covering-envelope prompt instead → confirm nothing was saved and no balances changed (FR-018).
5. Edit a previously saved, non-overspending expense's amount down → confirm the original amount is restored to its envelope before the new (smaller) amount is deducted (FR-018a).
6. Delete a previously saved expense that had triggered a coverage transfer → confirm both the source and covering envelopes' balances are restored and the coverage record is removed along with the expense.
7. Edit a previously saved, non-overspending expense's amount up past its envelope's balance → confirm the covering-envelope prompt triggers for the edit, same as a new entry.
8. With only one envelope in total, overspend it → confirm no covering-envelope prompt appears (nothing to select) and the envelope's balance simply goes negative (FR-016's no-other-envelope case).

## Verify: Overview and Account (User Story 4)

1. With a mix of positive and negative envelope balances, open Overview → confirm every envelope is listed with its balance, and negative ones are visually flagged (e.g. red) within 5 seconds of glancing at the screen (SC-005).
2. Confirm Overview is the tab shown immediately after sign-in (FR-023), and that it does not show any allocation-event history list (FR-022 — the data is persisted per FR-010, but has no UI here).
3. On the Account tab, update the avatar and change the password → confirm both persist and reflect immediately.
4. Sign out, relaunch the app → confirm the sign-in screen appears before Overview is reachable (FR-025).

## Verify: Offline behavior

1. Put the device in airplane mode → repeat the Plan and expense-entry flows above → confirm every write still succeeds immediately (Drift is the source of truth; the constitution requires the UI never block on network).
2. Re-enable connectivity → confirm the sync worker drains the outbox (inspect `sync_outbox` rows transitioning to `synced_at != null`, or confirm the rows appear in the Supabase tables) without any user action required.
3. After a sync completes, query the Supabase `envelope_balances` view and compare each envelope's `computed_balance` against its local Drift `balance` column → confirm they match exactly (research.md §2's server-authoritative reconciliation). Optionally force a mismatch (e.g. manually edit a synced row's amount directly in Supabase) and confirm the sync worker's next reconciliation pass surfaces a warning rather than silently overwriting either side.

## Automated test coverage checkpoint

Run `flutter test` → confirm:
- Unit tests cover the allocation calculation (rounding, over-allocation detection), overspend detection, and expense edit/delete reversal logic at ≥80% line coverage for `features/envelopes/domain/` and `features/expenses/domain/` (constitution Principle II gate).
- Widget tests pass for the Plan preview, expense entry + covering-envelope prompt, and Envelopes CRUD screens.
- The integration test (`allocate_spend_cover_flow_test.dart`) exercises allocate → spend → overspend-coverage end to end against an in-memory Drift database.
